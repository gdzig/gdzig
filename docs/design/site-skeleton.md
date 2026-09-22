# GDZig Site Skeleton

## Purpose and scope

This document defines the first GDZig site skeleton for issue #228. It gives implementation agents enough direction to build the v1 Astro and Starlight structure without inventing the site experience.

The skeleton must make the site useful for two audiences:

- **Extension developers** who want to build Godot GDExtensions in Zig.
- **Game developers** who want to decide whether Zig-backed Godot code fits their project.

This is a design contract, not the implementation. It does not add Astro, Starlight, Bun, routes, styles, generated-output copying, or deployment changes.

## Audiences and visitor goals

### Extension developers

Extension developers come to GDZig to build native Godot extension code with Zig. They need a path from first project to exact API lookup.

Their goals are:

- Learn how to create a GDZig extension.
- Register classes, methods, signals, and properties.
- Understand ownership, memory, and Godot type mapping.
- Use generated API documentation for exact symbols and signatures.
- Troubleshoot version and build problems.

### Game developers

Game developers come to GDZig to evaluate or use Zig-backed Godot code in a game project. They may not need to write every binding-level detail.

Their goals are:

- Understand what GDZig is and when to use it.
- See the current examples before committing to the toolchain.
- Find practical project status, version support, and caveats.
- Reach community help or project updates.
- Learn enough of the extension-developer path when they need custom native code.

The home page and docs landing page should expose both paths near the top. Do not create separate top-level audience routes in this skeleton. Use audience cards or similar entry points inside the main pages.

## Route map

Use this route map for the first site skeleton.

| Route | Owner | Purpose |
| --- | --- | --- |
| `/` | Astro page | Project home page with the audience gateway, project summary, examples, docs links, and visible stubs. |
| `/blog/` | Astro page | Blog index stub for future release notes and project updates. |
| `/blog/[slug]/` | Future Astro content route | Future individual blog posts. |
| `/showcase/` | Astro page | Showcase index stub for future community projects and examples. |
| `/showcase/[slug]/` | Future Astro content route | Future individual showcase entries. |
| `/docs/` | Starlight | Human-written docs landing page. |
| `/docs/tutorials/` | Starlight | Learning-oriented tutorials. |
| `/docs/how-to/` | Starlight | Task-oriented how-to guides. |
| `/docs/explanations/` | Starlight | Concept-oriented explanations. |
| `/docs/reference/` | Starlight | Curated, human-written project reference. |
| `/api/` | Copied Zig static output | Generated Zig API documentation. |

The `/docs/` section contains human-written documentation only. The `/api/` section contains the untouched generated Zig docs copied from `zig-out/docs/`. Keep `/api/` outside the Starlight sidebar and Starlight search for this version.

## Global navigation

Use one global navigation model across the Astro shell and the Starlight header where possible.

Primary navigation order:

1. GDZig logo or wordmark, linked to `/`.
2. Blog, linked to `/blog/`.
3. Showcase, linked to `/showcase/`.
4. Docs, linked to `/docs/`.
5. API Docs, linked to `/api/`.

GitHub and Discord are utility links. They should not compete with the main site sections. They can appear at the end of the desktop header, in a utility group, or inside the mobile menu after the primary links.

On mobile, collapse the same links into a menu. Keep the order stable. The user should not need to learn a different information architecture on small screens.

Inside Starlight docs, use the Starlight sidebar for Tutorials, How-to guides, Explanations, and Reference. Provide persistent links back to the main site and to `/api/`. The generated API docs can have their own static navigation, but they must still offer a visible path back to the main site or docs landing when implementation makes that possible.

## Landing page structure

Use an A/B hybrid landing structure. The exact component rhythm can be decided during Astro implementation, but the skeleton must follow these guardrails.

The home page should:

1. Start with a concise project statement based on the current README: GDZig provides idiomatic Zig bindings for Godot 4.
2. Show two primary actions: **Read the docs** and **Browse API docs**.
3. Present the two audience paths near the top.
4. Use current examples as supporting proof, not as the main story.
5. Show the four human-written docs categories.
6. Show Blog and Showcase as intentional stubs.

Do not lead with community proof in v1. The project has examples, but it does not yet have enough public showcase content to make community proof the first message.

Recommended audience cards:

- **Extension developers**: start with a first extension, learn registration patterns, and use generated API docs for exact bindings.
- **Game developers**: understand GDZig's use cases, inspect examples, and follow future showcase or blog content.

The page can include a small code panel. Keep it short and illustrative. Do not require final tutorial code during the skeleton issue.

## Documentation hierarchy

Starlight powers only the human-written docs area under `/docs/`. Use the Diátaxis categories as the main hierarchy. Audience cues can appear inside category pages, but the top-level docs hierarchy should remain task-intent based.

The docs landing page should help visitors answer two questions:

1. Which audience path fits me right now?
2. Which type of documentation do I need?

### Tutorials

Tutorials teach by guiding the reader through a complete learning path. They are the best starting point for users who are new to GDZig.

Representative future topics:

- Build a first GDZig project.
- Create a first registered class.
- Connect a small Zig extension to a Godot scene.

Audience notes:

- Extension developers use tutorials to learn the core extension workflow.
- Game developers use tutorials to understand what a GDZig-backed project looks like.

### How-to guides

How-to guides solve specific tasks. They assume the reader already knows the basic idea and wants a direct procedure.

Representative future topics:

- Build an extension.
- Register methods, signals, and properties.
- Troubleshoot version mismatch or build problems.
- Find the generated API documentation for a Godot type.

Audience notes:

- Extension developers are the primary audience for most how-to guides.
- Game developers may use selected guides when they adopt native code in a project.

### Explanations

Explanations describe concepts and tradeoffs. They answer why GDZig works the way it does.

Representative future topics:

- GDZig architecture.
- Ownership and memory.
- How GDZig maps Zig concepts to Godot concepts.
- Why generated API docs remain separate from human-written docs.

The existing `doc/memory.md` conceptually belongs in this future explanation area. Do not migrate or rewrite it as part of this ticket.

### Reference

Reference pages give curated human-written facts. They should complement generated API docs instead of replacing them.

Representative future topics:

- Supported Zig and Godot versions.
- Project conventions.
- Compatibility notes.
- WebAssembly caveats.

`/docs/reference/` is not the generated API reference. It is for maintained prose that explains project-level facts.

### Generated API documentation

Generated API documentation lives under `/api/`. It is copied static output from the Zig documentation build.

Rules for v1:

- Keep `/api/` outside the Starlight content tree.
- Keep `/api/` outside the Starlight sidebar.
- Keep `/api/` outside Starlight search unless a later issue chooses to integrate it.
- Link to `/api/` from the home page, docs landing page, and main navigation.
- Describe `/api/` as exact generated symbols and signatures, not as guided learning material.

## Placeholder copy

Visible stubs should feel intentional. They must not feel broken, abandoned, or misleading.

Rules:

- Label unfinished areas with a factual status such as **Planned** or **Guide in progress**.
- Say what content will live there.
- Say who the content will help when that is useful.
- Give one useful next action, such as the example project, API docs, GitHub, or Discord.
- Use direct present-tense sentences.
- Avoid hype, jokes, lorem ipsum, bare “Coming soon” messages, and claims that unfinished content exists.
- Keep index stubs to a heading, one or two sentences, and one action.

Ready-to-use examples:

```text
Blog — Planned
Release notes and project updates will live here. Until then, follow the repository for current changes.
```

```text
Showcase — Planned
Community projects built with GDZig will appear here. Use the example project while this section grows.
```

```text
Tutorials — Guide in progress
Tutorials will guide you through a complete GDZig project. Use the example project while the first guide is being written.
```

```text
API Docs
Generated Zig API documentation is available for exact symbols and signatures. Use it when you know the type or method you need.
```

```text
For extension developers
Start here if you want to build a Godot extension in Zig. The first guides will cover project setup, class registration, and generated API lookup.
```

```text
For game developers
Start here if you want to understand whether GDZig fits your Godot project. Begin with the example project and project status notes.
```

## Visual direction

Use the **warm technical** direction for v1. This is a lightweight direction, not a finished visual design.

### Layout

The layout should feel practical and readable. Use a conventional documentation-site structure with a stronger home page than generated API docs can provide alone.

Guidelines:

- Keep content width moderate. Avoid dense dashboard layouts.
- Put the hero, audience gateway, and primary calls to action above the fold when possible.
- Use cards for audience paths and documentation categories.
- Keep Blog and Showcase stubs lower than the docs and audience paths.
- Use examples as support, not as the main proof point.
- Let the implementation adjust exact section order after the Astro skeleton exists.

### Typography

Use dependency-free font stacks for the skeleton.

Recommended roles:

- Headings: system sans, bold, tight but readable.
- Body text: system sans, normal weight, generous line height.
- Code: system monospace.

Do not introduce novelty display fonts in v1. The site should feel like a serious engineering project, not a polished marketing launch.

### Color

Use the existing GDZig logo gold as the brand accent. The current gold reference is `#F6A31D`.

Recommended roles:

- Gold: active states, small accents, focus outlines, primary call-to-action background when contrast is sufficient.
- Near-black: body text and code surfaces.
- Warm off-white: page background and large surfaces.
- White or very light warm surfaces: cards and content panels.
- Low-contrast warm borders: section separation.

Do not use gold for long body text on light backgrounds. Do not use gradients or heavy decoration for the first skeleton.

### Brand feel

The brand should feel:

- practical,
- precise,
- warm,
- technically credible,
- welcoming to Godot users,
- honest about rapid development.

Avoid a community-proof-first tone until the project has more showcase content. Avoid a dark-only workshop identity for v1. A dark treatment can be explored later if the project wants a stronger code-first mood.

### Accessibility baseline

The skeleton should preserve basic accessibility from the start.

Requirements:

- All interactive elements need visible focus states.
- Text and controls must meet readable contrast targets.
- Navigation labels must be text, not only icons.
- The mobile menu must preserve all primary navigation links.
- Placeholder pages must load successfully and avoid dead-end navigation.
- Code examples must be short enough to scan and copy.

## Implementation boundaries

This ticket does not include:

- Astro or Starlight implementation.
- Bun setup.
- MDX content.
- Generated-output copying.
- Test automation.
- CI changes.
- Deployment changes.
- Content migration from `doc/`.
- Starlight search integration for generated API docs.
- Versioned documentation.
- Custom domains.
- Cross-repository publication to the organization Pages root.
- Polished visual branding.
- Final blog posts.
- Final showcase entries.

Later implementation can create site source files, build tasks, and artifact assembly. It should use this document as the UX and content contract.

## Acceptance checklist

- [x] The route map is documented for the landing page, blog, showcase, human-written docs, and generated API docs. See [Route map](#route-map).
- [x] The top-level navigation model is documented, including how visitors move between site sections. See [Global navigation](#global-navigation).
- [x] The Starlight-powered docs hierarchy is documented using tutorials, how-to guides, explanations, and reference. See [Documentation hierarchy](#documentation-hierarchy).
- [x] The placeholder copy tone is documented so visible stubs feel intentional and not broken. See [Placeholder copy](#placeholder-copy).
- [x] A lightweight visual direction is documented with layout, typography, color, and brand feel. See [Visual direction](#visual-direction).
- [x] The design keeps generated API docs under `/api/` and keeps cross-repository publishing out of scope. See [Generated API documentation](#generated-api-documentation) and [Implementation boundaries](#implementation-boundaries).
