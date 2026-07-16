# Symbiotic In Theory

A Jekyll blog hosted on GitHub Pages at
[symbioticintheory.github.io](https://symbioticintheory.github.io/). Each
post pairs a scanned/handwritten PDF note — journal entries, class notes,
whatever ends up on paper — with a bit of Markdown context, and renders
the PDF directly in the browser via a self-hosted PDF.js viewer, with no
forced downloads and no dependence on the browser's own PDF plugin (so it
works reliably on mobile too).

## Documentation

- [`milestones.md`](milestones.md) — the build-out plan (M1–M6) and
  status checkboxes for what's actually shipped vs. still planned. Start
  here for project status and the architecture decisions behind it.
- [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) — developer setup (full
  environment via `rbenv`/Bundler, or a lightweight machine for just
  adding posts), the Gemfile plugin list, PDF.js vendoring, and a
  step-by-step guide to adding a new post.
- [`docs/GITHUB_ACTIONS.md`](docs/GITHUB_ACTIONS.md) — how this repo's
  GitHub Actions build/deploy pipeline works, written for anyone who
  hasn't used Actions before.

## Quick start

```bash
bundle install
bundle exec jekyll serve   # http://localhost:4000
```

If `bundle` isn't available yet, see `docs/DEVELOPMENT.md` for full
environment setup, including `script/setup.sh`, which installs everything
in one shot.

## Adding a post

```bash
ruby script/new_post.rb "Title Of The Note" --topic <topic> --pdf <path> [--tags "a,b"]
```

See `docs/DEVELOPMENT.md` for the full walkthrough, including a
lightweight-machine-only workflow that doesn't need the full dev
environment above.

## Deployment

Pushes to `main` build and deploy automatically via GitHub Actions — see
`docs/GITHUB_ACTIONS.md`. There's no manual deploy step.
