import { beforeAll, describe, expect, test } from 'bun:test';
import { readFile, stat } from 'node:fs/promises';
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


function expectInOrder(html: string, values: string[]) {
  let lastIndex = -1;

  for (const value of values) {
    const index = html.indexOf(value);
    expect(index).toBeGreaterThan(lastIndex);
    lastIndex = index;
  }
}

function expectTopLevelNavigation(html: string) {
  expect(html).toContain('class="wordmark" href="/"');
  expectInOrder(html, ['href="/blog/"', 'href="/showcase/"', 'href="/docs/"', 'href="/api/"']);
}


function expectDocsTopLevelLinks(html: string) {
  for (const href of ['href="/"', 'href="/blog/"', 'href="/showcase/"', 'href="/docs/"', 'href="/api/"']) {
    expect(html).toContain(href);
  }
}


function expectDesktopMobileMenuHidden(css: string) {
  const hiddenRuleIndex = css.search(/\.pico \.mobile-nav\{[^}]*display:none/);
  const mobileMediaIndex = css.indexOf('@media (width<=576px){', hiddenRuleIndex);
  const visibleMobileRuleIndex = css.indexOf('.pico .mobile-nav{display:block}', mobileMediaIndex);

  expect(hiddenRuleIndex).toBeGreaterThanOrEqual(0);
  expect(mobileMediaIndex).toBeGreaterThan(hiddenRuleIndex);
  expect(visibleMobileRuleIndex).toBeGreaterThan(mobileMediaIndex);
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
}, 180_000);

describe('static site artifact', () => {
  test('contains the Astro landing page', async () => {
    const html = await readFile(join(outputDirectory, 'index.html'), 'utf8');

    expect(html).toContain('Idiomatic Zig bindings for Godot 4');
    expect(html).toContain('For extension developers');
    expect(html).toContain('For game developers');
    expect(html).toContain('href="/docs/"');
    expectTopLevelNavigation(html);
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


  test('hides the mobile menu on desktop widths', async () => {
    const html = await readFile(join(outputDirectory, 'index.html'), 'utf8');
    const css = await readLinkedCss(html);

    expect(html).toContain('class="mobile-nav"');
    expectDesktopMobileMenuHidden(css);
  });


  test('contains the Blog placeholder page', async () => {
    const html = await readFile(join(outputDirectory, 'blog', 'index.html'), 'utf8');

    expect(html).toContain('Blog — Planned');
    expect(html).toContain('Release notes and project updates will live here.');
    expect(html).toContain('Follow the repository');
    expect(html).toContain('href="https://github.com/gdzig/gdzig"');
    expectTopLevelNavigation(html);
  });

  test('contains the Showcase placeholder page', async () => {
    const html = await readFile(join(outputDirectory, 'showcase', 'index.html'), 'utf8');

    expect(html).toContain('Showcase — Planned');
    expect(html).toContain('Community projects built with GDZig will appear here.');
    expect(html).toContain('View the example project');
    expect(html).toContain('href="https://github.com/gdzig/gdzig/tree/master/example"');
    expectTopLevelNavigation(html);
  });

  test('contains browseable generated Zig API documentation', async () => {
    const apiDirectory = join(outputDirectory, 'api');
    const indexHtml = await readFile(join(apiDirectory, 'index.html'), 'utf8');
    const mainJavaScript = await readFile(join(apiDirectory, 'main.js'), 'utf8');
    const [mainWasm, sources] = await Promise.all([
      stat(join(apiDirectory, 'main.wasm')),
      stat(join(apiDirectory, 'sources.tar')),
    ]);

    expect(indexHtml).toContain('<title>Zig Documentation</title>');
    expect(indexHtml).toContain('<script src="main.js"></script>');
    expect(indexHtml).not.toContain('starlight');
    expect(mainJavaScript).toContain('fetch("main.wasm")');
    expect(mainJavaScript).toContain('fetch("sources.tar")');
    expect(mainWasm.size).toBeGreaterThan(0);
    expect(sources.size).toBeGreaterThan(0);
  });


  const docsSections = [
    ['tutorials', 'Tutorials — Guide in progress'],
    ['how-to', 'How-to guides — Guide in progress'],
    ['explanations', 'Explanations — Guide in progress'],
    ['reference', 'Reference — Guide in progress'],
  ];

  test.each(docsSections)('contains the %s docs placeholder page', async (slug, heading) => {
    const html = await readFile(join(outputDirectory, 'docs', slug, 'index.html'), 'utf8');

    expect(html).toContain(heading);
    expectDocsTopLevelLinks(html);
  });


  test('contains the Starlight docs landing page without Pico styles', async () => {
    const html = await readFile(join(outputDirectory, 'docs', 'index.html'), 'utf8');
    const css = await readLinkedCss(html);

    expect(html).toContain('GDZig documentation');
    expect(html).toContain('For extension developers');
    expect(html).toContain('For game developers');
    for (const href of [
      'href="/docs/tutorials/"',
      'href="/docs/how-to/"',
      'href="/docs/explanations/"',
      'href="/docs/reference/"',
      'href="/api/"',
    ]) {
      expect(html).toContain(href);
    }
    expectDocsTopLevelLinks(html);
    expect(html).not.toContain('class="pico');
    expect(css).not.toContain('--pico-font-family');
  });
});
