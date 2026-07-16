# Milestone Plan

Blog built on Jekyll, hosted on GitHub Pages, with each post displaying a
scanned/handwritten PDF rendered directly in the browser (no forced
downloads).

Status legend: `[ ]` not started · `[~]` in progress · `[x]` done

## M1 — Jekyll scaffold
- [x] Hand-built (not `jekyll new`, to avoid clobbering existing repo
      files) project structure: `Gemfile`, `_config.yml`
- [x] Base `_layouts` / `_includes` / `_sass` directories
- [x] GitHub Actions workflow to build and deploy to Pages (not the native
      Pages Jekyll build, so we aren't limited to its plugin whitelist)

**Exit criteria:** empty scaffold site builds via Actions and deploys to
`symbioticintheory.github.io`. Build/serve verified locally (`bundle exec
jekyll build` and `serve` both succeed); **not yet verified end-to-end via
Actions** — needs a push to `main` plus enabling "Build and deployment:
GitHub Actions" under the repo's Pages settings, both pending user
go-ahead.

## M2 — Theme & layout
- [ ] Header/nav, homepage post feed, single-post layout, about page, footer
- [ ] Responsive CSS in `_sass`
- [ ] Styled with placeholder posts only, no real content yet

**Exit criteria:** shell site looks and navigates correctly with dummy posts.

## M3 — Content model for PDF posts
- [ ] Front-matter schema for a PDF post (`layout: pdf-post`, `title`,
      `date`, `category`, `tags`, `pdf: /assets/pdfs/<category>/...`)
- [ ] Topic hierarchy: PDFs organized on disk under
      `assets/pdfs/<topic>/`, mirrored by the post's `category` front
      matter — browsable in the repo itself, not just via generated pages
- [x] `script/new_post.rb` — scaffolds a new post: copies the source PDF
      into `assets/pdfs/<topic>/`, creates the dated `_posts/` file with
      front matter filled in, leaves a placeholder for context text. See
      `docs/DEVELOPMENT.md` for usage.
- [ ] `pdf-post` layout that posts opt into via front matter; renders the
      post's Markdown body (the free-form context) above the embedded PDF
      viewer

**Exit criteria:** running `script/new_post.rb` produces a correctly
placed post + PDF pair; the resulting page shows context text above the
rendered PDF once M2/M4 layouts exist.

**Decision record:** topics are a single `category` per post (folder-
mirrored on disk) rather than a nested taxonomy — simpler to reason about
and enough for a personal notes blog; `tags` remain available for
cross-cutting labels that don't fit the topic hierarchy (e.g.
`midterm-review`). Context text is just the post's ordinary Markdown
body — no separate mechanism needed, the `pdf-post` layout just places
`{{ content }}` above the viewer iframe.

## M4 — PDF embedding mechanism
- [ ] Vendor the PDF.js "generic" release into `/assets/pdfjs/`
- [ ] `pdf-post` layout embeds `web/viewer.html?file=...` in an iframe
- [ ] Verify in-browser rendering (no download prompt) on desktop Chrome/
      Firefox, iOS Safari, and Android Chrome

**Exit criteria:** a real PDF renders inline in-browser on every target
device with zero download prompts.

**Decision record:** rejected native `<embed>`/`<iframe>` pointing directly
at the PDF (relies on the OS/browser's own PDF plugin — unavailable in some
mobile/in-app browsers, silently falls back to download). Rejected
PDFObject.js for the same reason — its whole design is "use native
rendering, fall back to a download link if unsupported." Self-hosted PDF.js
renders the PDF itself via canvas/JS, so behavior doesn't depend on the
viewer's platform.

## M5 — Post-list polish
- [ ] Cover thumbnails (render page 1 of each PDF to an image)
- [ ] Tags/categories
- [ ] Pagination

**Exit criteria:** homepage feed is scannable, not a wall of identical PDF
icons.

## M6 — Migrate real content
- [ ] Convert existing PDFs into actual posts
- [ ] Verify viewer behavior on desktop + mobile for real content
- [ ] Fix anything ugly

**Exit criteria:** site is live with real handwritten-note posts.
