// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  output: 'static',
  trailingSlash: 'always',
  integrations: [
    starlight({
      title: 'GDZig Docs',
      description: 'Human-written guides for building Godot extensions with Zig.',
      customCss: ['./src/styles/starlight.css'],
      components: {
        SocialIcons: './src/components/StarlightUtilityLinks.astro',
      },
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/gdzig/gdzig' },
        { icon: 'discord', label: 'Discord', href: 'https://discord.gg/GEUZGRGeDj' },
      ],
      sidebar: [
        { label: 'Home', link: '/' },
        { label: 'Blog', link: '/blog/' },
        { label: 'Showcase', link: '/showcase/' },
        {
          label: 'Documentation',
          collapsed: false,
          items: [
            { label: 'Overview', link: '/docs/' },
            { label: 'Tutorials', link: '/docs/tutorials/' },
            { label: 'How-to guides', link: '/docs/how-to/' },
            {
              label: 'Explanations',
              collapsed: false,
              items: [
                { label: 'Overview', link: '/docs/explanations/' },
                {
                  label: 'Choosing math and random APIs',
                  link: '/docs/explanations/math-and-random-apis/',
                },
              ],
            },
            { label: 'Reference', link: '/docs/reference/' },
          ],
        },
      ],
    }),
  ],
});
