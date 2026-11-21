# Pomodoro Timer

React + Vite + Tailwind CSS project exported from Figma Make.

## Development

- Install dependencies with `pnpm install --frozen-lockfile`.
- Start the local server with `pnpm dev` (default port 8443).
- Run `pnpm typecheck` and `pnpm build` after source changes.
- Use `pnpm format` for formatting.

## Project Structure

- `src/main.tsx` — React entrypoint.
- `src/App.tsx` — timer state and section navigation.
- `src/components/` — reusable UI, sidebar, reset dialog.
- `src/pages/` — home, timer, and placeholder views.
- `src/types.ts` — shared section and timer types.
- `src/utils/formatTime.ts` — timer display formatting.
- `src/styles/index.css` — global styles and Tailwind entrypoint.
- `public/` — static assets.
- `task.md` — coursework requirements.
- `submission/` — product scenario and mockup creation notes.
- `config/vite.config.ts` — local Vite configuration; no Figma runtime required.

Read task-relevant files first. Follow imports only as needed.

## Styling

This project uses **Tailwind CSS v4** through the `@tailwindcss/vite` plugin configured in `config/vite.config.ts`. `src/styles/index.css` imports Tailwind with `@import 'tailwindcss';`. Use Tailwind utility classes directly in JSX and put global CSS or Tailwind v4 theme customization in `src/styles/index.css`. This scaffold does not need a Tailwind config file or PostCSS config.

`src/main.tsx` imports `src/styles/index.css`, so global font wiring belongs in `src/styles/index.css`. Keep CSS `@import` statements first, then add any `@font-face` rules and font-family defaults there.

Tailwind emits utility classes in `@layer utilities`, and CSS outside any cascade layer overrides every layer regardless of specificity. Put global element styles, such as resets and defaults for `body`, headings, `button`, or `input`, inside `@layer base { ... }` so utility classes on those elements still apply. Tailwind's Preflight already applies `box-sizing: border-box`, removes default margins, and sets `font: inherit` on form controls, so do not repeat those rules.
