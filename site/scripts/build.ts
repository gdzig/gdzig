import { cp } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const siteDirectory = join(scriptDirectory, '..');
const repositoryDirectory = join(siteDirectory, '..');

function run(command: string, arguments_: string[], cwd: string) {
  const result = spawnSync(command, arguments_, { cwd, stdio: 'inherit' });

  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}

run('zig', ['build', 'docs'], repositoryDirectory);
run('bun', ['run', 'build:astro'], siteDirectory);
await cp(join(repositoryDirectory, 'zig-out', 'docs'), join(siteDirectory, 'dist', 'api'), {
  recursive: true,
});
