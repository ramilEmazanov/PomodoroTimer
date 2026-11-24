# Pomodoro Timer

React + Vite + Tailwind CSS project exported from Figma Make.

## Development

- Install dependencies with `pnpm install --frozen-lockfile`.
- Start the local server with `pnpm dev` (default port 8443).
- Run `pnpm typecheck` and `pnpm build` after source changes.
- Use `pnpm format` for formatting.
- After completing changes and passing the required checks, create a Git commit with a clear message describing the changes. Commit only files relevant to the task. Do not push unless explicitly requested. Skip the commit if the user asks not to commit.

## Native macOS application

- `macOS/` — native SwiftUI application with a local SQLite backend; see `macOS/README.md`.
- Build native changes with `cd macOS && swift build`; package with `bash macOS/scripts/build-app.sh` from the repository root.
- Format Swift with `swift format format --in-place --recursive macOS/Sources macOS/Package.swift`.
- Run `cd macOS && swift test` after native backend changes. Tests use isolated stores; never use the real user database for test fixtures.
- Local sessions, active timer and preferences are persisted by `FocusStore.swift`. Session writes and clearing the active timer must stay in one transaction.
- Format tests together with sources: `swift format format --in-place --recursive macOS/Sources macOS/Tests macOS/Package.swift`.

## Project Structure

- `src/main.tsx` — React entrypoint.
- `src/App.tsx` — timer state and section navigation.
- `src/components/` — reusable UI, sidebar, reset dialog.
- `src/pages/` — home, timer, and placeholder views.
- `src/types.ts` — shared section and timer types.
- `src/utils/formatTime.ts` — timer display formatting.
- `src/styles/index.css` — global styles and Tailwind entrypoint.
- `public/` — static assets.
- `config/vite.config.ts` — local Vite configuration; no Figma runtime required.

Read task-relevant files first. Follow imports only as needed.

## Styling

This project uses **Tailwind CSS v4** through the `@tailwindcss/vite` plugin configured in `config/vite.config.ts`. `src/styles/index.css` imports Tailwind with `@import 'tailwindcss';`. Use Tailwind utility classes directly in JSX and put global CSS or Tailwind v4 theme customization in `src/styles/index.css`. This scaffold does not need a Tailwind config file or PostCSS config.

`src/main.tsx` imports `src/styles/index.css`, so global font wiring belongs in `src/styles/index.css`. Keep CSS `@import` statements first, then add any `@font-face` rules and font-family defaults there.

Tailwind emits utility classes in `@layer utilities`, and CSS outside any cascade layer overrides every layer regardless of specificity. Put global element styles, such as resets and defaults for `body`, headings, `button`, or `input`, inside `@layer base { ... }` so utility classes on those elements still apply. Tailwind's Preflight already applies `box-sizing: border-box`, removes default margins, and sets `font: inherit` on form controls, so do not repeat those rules.
