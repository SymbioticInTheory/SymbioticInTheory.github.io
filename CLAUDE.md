# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Jekyll blog hosted on GitHub Pages (`symbioticintheory.github.io`). Each
post displays a scanned/handwritten note that currently exists as a PDF
file; the core technical problem this repo solves is rendering those PDFs
directly in-browser (no forced downloads, works on mobile).

**Current state: pre-scaffold.** Only planning docs and a placeholder
`index.html` exist so far — no Gemfile, no `_config.yml`, no Jekyll
structure yet. See `milestones.md` for the build-out plan (M1–M6) before
assuming any Jekyll files are present.

- `milestones.md` — the milestone plan and its status checkboxes. Check
  this first to see what's actually been built vs. still planned.
- `docs/DEVELOPMENT.md` — setup commands, Gemfile plugin list with
  rationale, and the PDF.js vendoring/update procedure.

## Commands

Once the Jekyll scaffold lands (M1), the standard commands are:

```bash
bundle install              # install Jekyll + plugins from Gemfile
bundle exec jekyll serve    # local dev server at http://localhost:4000
bundle exec jekyll build    # one-off static build into _site/
```

There is no test suite or linter configured. Deploys happen via a GitHub
Actions workflow on push to `main` (not GitHub's native Pages Jekyll
build) — see the architecture note below for why.

## Architecture decisions to preserve

- **Deploy via GitHub Actions, not native Pages Jekyll build.** The native
  build only allows a whitelisted set of plugins; a custom Actions workflow
  (checkout → `ruby/setup-ruby` → `bundle exec jekyll build` →
  `actions/upload-pages-artifact` → `actions/deploy-pages`) removes that
  constraint.
- **PDF rendering uses a self-hosted PDF.js viewer, not native
  `<embed>`/`<iframe>` or PDFObject.js.** Native inline PDF viewing depends
  on the browser/OS having a PDF plugin, which isn't guaranteed on mobile
  and silently falls back to a download — unacceptable per the project's
  requirement of zero download prompts. PDF.js renders the PDF itself via
  canvas/JS, so behavior is identical across all platforms. It's vendored
  as static files into `assets/pdfjs/` (not installed via a package
  manager), embedded per-post via
  `assets/pdfjs/web/viewer.html?file=<pdf-path>` in an iframe. Full
  rationale is in `milestones.md` under M4.
- **Tag pages use a plain Liquid loop over `site.tags`, not a plugin.** The
  obvious plugin (`jekyll-tagsgenerator`) is unmaintained since ~2018;
  Jekyll's built-in tag data is sufficient without it.
