import { beforeAll, describe, expect, test } from 'bun:test';
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const testDirectory = dirname(fileURLToPath(import.meta.url));
const siteDirectory = join(testDirectory, '..');
const outputDirectory = join(siteDirectory, 'dist');


async function readLinkedCss(html: string) {
  const stylesheetPaths = [...html.matchAll(/href="(\/_astro\/[^\"]+\.css)"/g)].map(
    ([, path]) => path,
  );

  return (
    await Promise.all(
      stylesheetPaths.map((path) => readFile(join(outputDirectory, path.slice(1)), 'utf8')),
    )
  ).join('\n');
}

beforeAll(() => {
  const result = spawnSync('bun', ['run', 'build'], {
    cwd: siteDirectory,
    encoding: 'utf8',
  });

  if (result.status !== 0) {
    throw new Error(
      ['Site build failed.', result.stdout, result.stderr].filter(Boolean).join('\n'),
    );
  }
}, 60_000);

describe('static site artifact', () => {
  test('contains the Astro landing page', async () => {
    const html = await readFile(join(outputDirectory, 'index.html'), 'utf8');

    expect(html).toContain('Idiomatic Zig bindings for Godot 4');
    expect(html).toContain('For extension developers');
    expect(html).toContain('For game developers');
    expect(html).toContain('href="/docs/"');
  });


  test('supports a system-aware remembered color theme', async () => {
    const html = await readFile(join(outputDirectory, 'index.html'), 'utf8');
    const css = await readLinkedCss(html);

    expect(html).toContain('id="theme-toggle"');
    expect(html).toContain('starlight-theme');
    expect(html).toContain('prefers-color-scheme: dark');
    expect(css).toContain('[data-theme=dark]');
  });


  test('includes scoped Pico styles on the Astro landing page', async () => {
    const html = await readFile(join(outputDirectory, 'index.html'), 'utf8');
    const css = await readLinkedCss(html);

    expect(html).toContain('class="pico home-page"');
    expect(css).toContain('--pico-font-family');
    expect(css).toContain('.pico');
  });

  test('contains the Starlight docs landing page without Pico styles', async () => {
    const html = await readFile(join(outputDirectory, 'docs', 'index.html'), 'utf8');
    const css = await readLinkedCss(html);

    expect(html).toContain('GDZig documentation');
    expect(html).toContain('For extension developers');
    expect(html).toContain('For game developers');
    expect(html).not.toContain('class="pico');
    expect(css).not.toContain('--pico-font-family');
  });
});
