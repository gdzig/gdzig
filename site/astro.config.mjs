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
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/gdzig/gdzig' },
        { icon: 'discord', label: 'Discord', href: 'https://discord.gg/GEUZGRGeDj' },
      ],
      sidebar: [
        { label: 'GDZig home', link: '/' },
        { label: 'Documentation', link: '/docs/' },
      ],
    }),
  ],
});
