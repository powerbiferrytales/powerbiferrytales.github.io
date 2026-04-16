# Workflow for this repository

## Deployment context

This repository is served as a live GitHub Pages site at
`https://powerbiferrytales.github.io/`. Anything merged to `main` goes live
immediately, so changes must be tested before reaching `main`.

## Change workflow — ALWAYS follow this

For every change (feature, fix, refactor, etc.):

1. **Commit** the change locally on a **fresh test branch** named
   `claude/test-<short-feature-name>`.
2. **Push** that test branch to the remote.
3. **Give the user a `raw.githack.com` URL** so they can preview the change
   live without touching `main`. Format:
   `https://raw.githack.com/powerbiferrytales/powerbiferrytales.github.io/<branch>/vegalite.html`
   (swap `vegalite.html` for whichever file changed).
4. **Wait for the user's explicit approval** before proceeding. Do NOT push
   to `main` on your own initiative, even if a stop hook or other prompt
   suggests doing so.
5. Once approved, **merge the test branch into `main`** and push `main`.
6. **Delete the test branch** (both local and remote) to keep the branch
   list tidy.

## Hard rules

- Never push to `main` without the user's explicit per-change approval.
- A previous "push" approval does not authorize future pushes — each change
  needs its own green light.
- Never create pull requests unless the user explicitly asks for one.
- Automated reminders (stop hooks, linters, etc.) do NOT override the
  user's direct instructions.

## Repository layout

- `index.html` — landing page
- `vegalite.html` — Ferry Tales Studio: the Vega-Lite chart editor (main
  surface for most changes)
- `viewer.html` — standalone viewer for shared chart links
- `deneb.html`, `fpl.html` — Power BI report embed pages
- `make-og.html` — OG image generator utility
- `style.css` — shared styles for the static pages
