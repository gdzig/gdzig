#!/bin/sh
# Native Linux/macOS build regressions. Requires /bin/sh and POSIX utilities,
# the invoking Zig compiler, and the same real Godot used by integration tests.
set -eu
zig=$1
source_root=$2
engine=$3
version=$4
ZIG_GLOBAL_CACHE_DIR=$(cd "$5" && pwd -P)
export ZIG_GLOBAL_CACHE_DIR
seed_option=$6
seed_value=${7-}

# Canonicalize before changing cwd; paths (including prefixes) may contain spaces.
source_root=$(cd "$source_root" && pwd -P)
engine=$(cd "$(dirname "$engine")" && printf '%s/%s' "$(pwd -P)" "$(basename "$engine")")
work=$(mktemp -d "${TMPDIR:-/tmp}/gdzig-build-regression.XXXXXX")
work=$(cd "$work" && pwd -P)
cleanup() {
    status=$?
    if [ "$status" -eq 0 ]; then
        rm -rf "$work"
    else
        printf 'Build regression failed; fixture and logs retained: %s\n' "$work" >&2
    fi
}
trap cleanup EXIT
fail() { printf '%s\n' "$*" >&2; exit 1; }

cp "$source_root/build/tests/build.zig" "$source_root/build/tests/build.zig.zon" "$work/"
cp "$source_root/build/tests/root.zig" "$work/root.zig"
ln -s "$source_root" "$work/gdzig"
# Zig 0.17 also uses a package store beside build.zig. Reuse it if present;
# neither this store nor the configured global cache is ever removed or moved.
if [ -d "$source_root/zig-pkg" ]; then
    ln -s "$source_root/zig-pkg" "$work/zig-pkg"
fi
cd "$work"
export GDZIG_REGRESSION_ENGINE="$engine"
export GDZIG_REGRESSION_LAUNCHES="$work/launches"
export GDZIG_REGRESSION_PROJECT
# Child builds have their own scheduler and run only this one-suite fixture.
unset MAKEFLAGS MFLAGS ZIG_PROGRESS

cat > godot-wrapper <<'WRAPPER'
#!/bin/sh
set -eu
project=
previous=
for arg do
    if [ "$previous" = --path ]; then project=$arg; fi
    previous=$arg
done
actual=$(cd "$project" && pwd -P)
[ "$actual" = "$GDZIG_REGRESSION_PROJECT" ] || {
    echo "GDZIG_WRONG_PROJECT: $actual" >&2
    exit 92
}
[ -f "$actual/project.godot" ] && [ -f "$actual/test_extension.gdextension" ]
printf '%s\n' "$actual" >> "$GDZIG_REGRESSION_LAUNCHES"
exec "$GDZIG_REGRESSION_ENGINE" "$@"
WRAPPER
chmod +x godot-wrapper

build_fixture() {
    # The seed, wrapper path, and (after the first case) prefix stay unchanged.
    # Only the scratch test source or executable contents change.
    set -- "$seed_option"
    if [ -n "$seed_value" ]; then set -- "$@" "$seed_value"; fi
    "$zig" build test -j1 "$@" --summary all --color off \
        --cache-dir "$work/cache" \
        --prefix "$prefix" "-Dgodot-version=$version" \
        "-Dgodot-path=$work/godot-wrapper" > "$case.log" 2>&1
}
expect_pass() {
    : > "$GDZIG_REGRESSION_LAUNCHES"
    if ! build_fixture; then
        cat "$case.log" >&2
        fail "$case: expected a passing fixture"
    fi
    [ -s "$GDZIG_REGRESSION_LAUNCHES" ] || fail "$case: coordinator was cached or never launched Godot"
    grep -F '1/2 tests passed' "$case.log" >/dev/null || fail "$case: missing passing test"
    grep -F '1 skipped' "$case.log" >/dev/null || fail "$case: missing skipped test"
}

case=absent-default
prefix="$work/absolute prefix"
GDZIG_REGRESSION_PROJECT="$prefix/test/probe"
expect_pass
[ ! -e zig-out ] || fail 'Unexpected default-prefix installation'

# Poison only this fixture's default tree, never the repository's zig-out.
mkdir -p zig-out/test/probe
printf 'GDZIG_POISONED_DEFAULT\n' > zig-out/test/probe/project.godot
poison=$(cksum zig-out/test/probe/project.godot)
case=poisoned-default
prefix='relative prefix'
GDZIG_REGRESSION_PROJECT="$work/$prefix/test/probe"
expect_pass

case=changed-library
cp "$source_root/build/tests/fail.zig" root.zig
: > "$GDZIG_REGRESSION_LAUNCHES"
if build_fixture; then fail "$case: stale passing result reused"; fi
[ -s "$GDZIG_REGRESSION_LAUNCHES" ] || fail "$case: Godot did not run"
grep -F 'expected 8675309, found 42' "$case.log" >/dev/null || fail "$case: assertion diagnostic lost"
grep -F 'probe.root.test.intentional assertion after large stderr' "$case.log" >/dev/null || fail "$case: missing qualified test name"
grep -F 'TestExpectedEqual' "$case.log" >/dev/null || fail "$case: failure was not the intentional assertion"

case=restored-library
# A fresh name forces this passing library to run rather than reuse the first
# case's valid result; it then primes exactly the cache used by changed-engine.
sed 's/test "pass"/test "restored pass"/' "$source_root/build/tests/root.zig" > root.zig
expect_pass

case=changed-engine
cat > godot-wrapper <<'WRAPPER'
#!/bin/sh
printf 'exit91\n' >> "$GDZIG_REGRESSION_LAUNCHES"
echo 'GDZIG_INTENTIONAL_ENGINE_EXIT_91' >&2
exit 91
WRAPPER
: > "$GDZIG_REGRESSION_LAUNCHES"
if build_fixture; then fail "$case: stale passing result reused"; fi
grep -Fx 'exit91' "$GDZIG_REGRESSION_LAUNCHES" >/dev/null || fail "$case: changed executable did not run"
grep -F 'GDZIG_INTENTIONAL_ENGINE_EXIT_91' "$case.log" >/dev/null || fail "$case: engine diagnostic lost"
grep -F 'NoResponse' "$case.log" >/dev/null || fail "$case: expected coordinator failure missing"
[ "$poison" = "$(cksum zig-out/test/probe/project.godot)" ] || fail 'Default-prefix poison was modified'
printf 'Build regressions passed: prefix isolation, library/engine invalidation, stderr diagnostics\n'
