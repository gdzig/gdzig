pub fn run() !void {
    try testBasicConstruction();
    try testClone();
    try testStringify();
    try testBooleanize();
    try testHash();
    try testDuplicate();
    try testTagHelpers();
    try testOperators();
}

fn testBasicConstruction() !void {
    const nil = Variant.nil;
    try testing.expectEqual(Variant.Tag.nil, nil.tag);

    const int = Variant.init(i64, 42);
    try testing.expectEqual(Variant.Tag.int, int.tag);

    const float = Variant.init(f64, 3.14);
    try testing.expectEqual(Variant.Tag.float, float.tag);

    const @"bool" = Variant.init(bool, true);
    try testing.expectEqual(Variant.Tag.bool, @"bool".tag);

    var str = String.fromLatin1("hello");
    defer str.deinit();
    const str_var = Variant.init(String, str);
    defer str_var.deinit();
    try testing.expectEqual(Variant.Tag.string, str_var.tag);
}

fn testClone() !void {
    const original = Variant.init(i64, 123);
    defer original.deinit();

    const cloned = original.clone();
    defer cloned.deinit();

    try testing.expectEqual(Variant.Tag.int, cloned.tag);
    const cloned_val = cloned.as(i64) orelse return error.CastFailed;
    try testing.expectEqual(@as(i64, 123), cloned_val);
}

fn testStringify() !void {
    const int = Variant.init(i64, 42);
    defer int.deinit();

    var string = int.stringify();
    defer string.deinit();

    var buf: [64]u8 = undefined;
    const slice = string.toUtf8Buf(&buf);
    try testing.expectEqualStrings("42", slice);
}

fn testBooleanize() !void {
    const int = Variant.init(i64, 1);
    defer int.deinit();
    try testing.expect(int.booleanize());

    const zero_var = Variant.init(i64, 0);
    defer zero_var.deinit();
    try testing.expect(!zero_var.booleanize());

    try testing.expect(!Variant.nil.booleanize());

    const true_var = Variant.init(bool, true);
    defer true_var.deinit();
    try testing.expect(true_var.booleanize());

    const false_var = Variant.init(bool, false);
    defer false_var.deinit();
    try testing.expect(!false_var.booleanize());
}

fn testHash() !void {
    const var1 = Variant.init(i64, 42);
    defer var1.deinit();

    const var2 = Variant.init(i64, 42);
    defer var2.deinit();

    const var3 = Variant.init(i64, 43);
    defer var3.deinit();

    try testing.expectEqual(var1.hash(), var2.hash());
    try testing.expect(var1.hashCompare(var2));
    try testing.expect(!var1.hashCompare(var3));
}

fn testDuplicate() !void {
    const int = Variant.init(i64, 42);
    defer int.deinit();

    const shallow = int.duplicate(false);
    defer shallow.deinit();
    try testing.expectEqual(Variant.Tag.int, shallow.tag);
    const shallow_val = shallow.as(i64) orelse return error.CastFailed;
    try testing.expectEqual(@as(i64, 42), shallow_val);

    const deep = int.duplicate(true);
    defer deep.deinit();
    try testing.expectEqual(Variant.Tag.int, deep.tag);
    const deep_val = deep.as(i64) orelse return error.CastFailed;
    try testing.expectEqual(@as(i64, 42), deep_val);
}

fn testTagHelpers() !void {
    var int_name = Variant.Tag.int.getName();
    defer int_name.deinit();
    var buf1: [64]u8 = undefined;
    const int_slice = int_name.toUtf8Buf(&buf1);
    try testing.expectEqualStrings("int", int_slice);

    var string_name = Variant.Tag.string.getName();
    defer string_name.deinit();
    var buf2: [64]u8 = undefined;
    const str_slice = string_name.toUtf8Buf(&buf2);
    try testing.expectEqualStrings("String", str_slice);

    try testing.expect(Variant.Tag.canConvert(.int, .float));
    try testing.expect(Variant.Tag.canConvert(.int, .string));
    try testing.expect(Variant.Tag.canConvert(.float, .int));

    try testing.expect(Variant.Tag.canConvertStrict(.int, .int));
}

fn testOperators() !void {
    const a = Variant.init(i64, 10);
    defer a.deinit();
    const b = Variant.init(i64, 5);
    defer b.deinit();

    const sum = try a.add(b);
    defer sum.deinit();
    const sum_val = sum.as(i64) orelse return error.CastFailed;
    try testing.expectEqual(@as(i64, 15), sum_val);

    const diff = try a.sub(b);
    defer diff.deinit();
    const diff_val = diff.as(i64) orelse return error.CastFailed;
    try testing.expectEqual(@as(i64, 5), diff_val);

    const prod = try a.mul(b);
    defer prod.deinit();
    const prod_val = prod.as(i64) orelse return error.CastFailed;
    try testing.expectEqual(@as(i64, 50), prod_val);

    const quot = try a.div(b);
    defer quot.deinit();
    const quot_val = quot.as(i64) orelse return error.CastFailed;
    try testing.expectEqual(@as(i64, 2), quot_val);

    try testing.expect(a.eql(a));
    try testing.expect(!a.eql(b));

    try testing.expect(a.notEql(b));
    try testing.expect(!a.notEql(a));

    try testing.expect(b.lessThan(a));
    try testing.expect(!a.lessThan(b));

    try testing.expect(a.greaterThan(b));
    try testing.expect(!b.greaterThan(a));

    try testing.expect(b.lessThanOrEql(a));
    try testing.expect(a.lessThanOrEql(a));

    try testing.expect(a.greaterThanOrEql(b));
    try testing.expect(a.greaterThanOrEql(a));

    const remainder = try a.mod(b);
    defer remainder.deinit();
    const mod_val = remainder.as(i64) orelse return error.CastFailed;
    try testing.expectEqual(@as(i64, 0), mod_val); // 10 % 5 = 0

    const negated = try a.neg();
    defer negated.deinit();
    const neg_val = negated.as(i64) orelse return error.CastFailed;
    try testing.expectEqual(@as(i64, -10), neg_val);

    const c = Variant.init(i64, 2);
    defer c.deinit();
    const d = Variant.init(i64, 3);
    defer d.deinit();
    const power = try c.pow(d);
    defer power.deinit();
    const pow_val = power.as(i64) orelse return error.CastFailed;
    try testing.expectEqual(@as(i64, 8), pow_val); // 2^3 = 8
}

const godot = @import("gdzig");
const String = godot.builtin.String;
const Variant = godot.builtin.Variant;
const testing = @import("gdzig_test");
