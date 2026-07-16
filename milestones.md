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
`symbioticintheory.github.io`. Verified end-to-end: pushed to `main`,
Pages source set to "GitHub Actions" in repo settings, workflow ran, and
the placeholder homepage is live at https://symbioticintheory.github.io/.

## M2 — Theme & layout
- [x] Header/nav, homepage post feed, single-post layout, about page, footer
- [x] Responsive CSS in `_sass`
- [x] Styled with placeholder posts only, no real content yet

**Exit criteria:** shell site looks and navigates correctly with dummy
posts. Verified via build/serve: homepage paginates correctly (5 posts on
page 1, 1 on page 2, per `paginate: 5`), About and Tags pages render, tag
listing is sorted and links back to posts, nav resolves on every page.
**Not yet visually reviewed in a real browser** — I don't have a browser
tool to screenshot with, so styling/responsiveness should get an eyeball
pass (`bundle exec jekyll serve`) before calling this fully done.

**Decision record:** `index.html` (not `.md`) at the site root, using a
`home` layout — `jekyll-paginate` (classic) only paginates a page
literally named `index.html`. Nav includes a `/tags/` link even though
M5 is titled "Post-list polish" — the tag-listing mechanism itself (plain
Liquid loop over `site.tags`, per the `CLAUDE.md` decision to skip
`jekyll-tagsgenerator`) was simple enough to build now rather than ship a
dead nav link; M5's remaining scope is thumbnails and feed pagination
polish. Six placeholder posts (`_posts/2026-06-*` through `2026-07-*`,
category `sandbox`/`meta`) exist solely to exercise the feed/pagination/
tags — replace or remove them in M3/M6 once real posts land.

## M3 — Content model for PDF posts
- [x] Front-matter schema for a PDF post (`layout: pdf-post`, `title`,
      `date`, `category`, `tags`, `pdf: /assets/pdfs/<category>/...`)
- [x] Topic hierarchy: PDFs organized on disk under
      `assets/pdfs/<topic>/`, mirrored by the post's `category` front
      matter — browsable in the repo itself, not just via generated pages
- [x] `script/new_post.rb` — scaffolds a new post: copies the source PDF
      into `assets/pdfs/<topic>/`, creates the dated `_posts/` file with
      front matter filled in, leaves a placeholder for context text. See
      `docs/DEVELOPMENT.md` for usage.
- [x] `pdf-post` layout that posts opt into via front matter; renders the
      post's Markdown body (the free-form context) above the embedded PDF
      viewer

**Exit criteria:** running `script/new_post.rb` produces a correctly
placed post + PDF pair; the resulting page shows context text above the
rendered PDF once M2/M4 layouts exist. Verified end-to-end with a
throwaway dummy PDF (`_posts/2026-07-16-scaffold-verification-note.md`,
category `sandbox`): front matter matches the schema exactly, and the
built page renders title/date/category/tags, then the Markdown context
text, then a `.pdf-viewer` iframe — in that order. The iframe's `src`
already points at the final target path
(`/assets/pdfjs/web/viewer.html?file=...`), so it 404s until M4 vendors
PDF.js; that's expected and is M4's job, not M3's. Remove the
verification post once M4 lands (it'll get a real PDF.js-rendered demo
then anyway) and once M6 migrates the real journal PDFs.

**Decision record:** `pdf-post`'s title/date/category/tags header is
identical to the plain `post` layout's, so it was factored into a shared
`_includes/post-meta.html` rather than duplicated — both layouts now
just `{% include post-meta.html %}`. The PDF-viewer iframe's `src` was
written now (M3) pointing at PDF.js's eventual vendored path rather than
left as a placeholder, since M4's own checklist already calls out "layout
embeds `web/viewer.html?file=...` in an iframe" as its task — building it
here means M4 only has to vendor the files and cross-browser-verify, not
touch the layout again.

**Decision record:** topics are a single `category` per post (folder-
mirrored on disk) rather than a nested taxonomy — simpler to reason about
and enough for a personal notes blog; `tags` remain available for
cross-cutting labels that don't fit the topic hierarchy (e.g.
`midterm-review`). Context text is just the post's ordinary Markdown
body — no separate mechanism needed, the `pdf-post` layout just places
`{{ content }}` above the viewer iframe.

## M4 — PDF embedding mechanism
- [ ] Vendor the PDF.js "generic" release into `/assets/pdfjs/`
- [x] `pdf-post` layout embeds `web/viewer.html?file=...` in an iframe
      (built early, in M3 — see its decision record)
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
