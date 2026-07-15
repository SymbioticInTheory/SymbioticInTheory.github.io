# Developer Setup & Dependencies

This project is a static Jekyll site deployed to GitHub Pages via a custom
GitHub Actions workflow (not the native Pages Jekyll build), which is what
lets us use plugins outside GitHub's built-in plugin whitelist.

## Prerequisites

- Ruby (3.x) and Bundler

```bash
# check versions
ruby -v
gem -v

# install bundler if missing
gem install bundler
```

Ruby 3.0+ removed `webrick` from the standard library, and Jekyll's local
dev server depends on it, so it's listed explicitly in the Gemfile below.

## Installing the project

```bash
bundle install       # installs Jekyll + all plugins from the Gemfile
bundle exec jekyll serve   # local dev server at http://localhost:4000
bundle exec jekyll build   # one-off static build into _site/
```

## Gemfile plugins

| Gem | Purpose |
|---|---|
| `jekyll` | Static site generator itself. |
| `webrick` | HTTP server used by `jekyll serve`; no longer bundled with Ruby 3+. |
| `jekyll-seo-tag` | Injects `<meta>`/Open Graph/Twitter Card tags per page from front matter, without hand-writing them. |
| `jekyll-sitemap` | Auto-generates `sitemap.xml` for search engine crawling. |
| `jekyll-feed` | Auto-generates an RSS/Atom feed (`/feed.xml`) from posts. |
| `jekyll-paginate` | Splits the homepage post list into pages (`paginate:` in `_config.yml`). Simple and sufficient for a single chronological feed; if we later need pagination on tag/category pages too, swap to the actively-maintained `jekyll-paginate-v2` instead. |

Add each with `bundle add <gem> --group jekyll_plugins`, or add manually to
the Gemfile:

```ruby
source "https://rubygems.org"

gem "jekyll", "~> 4.3"
gem "webrick", "~> 1.8"

group :jekyll_plugins do
  gem "jekyll-seo-tag"
  gem "jekyll-sitemap"
  gem "jekyll-feed"
  gem "jekyll-paginate"
end
```

Then run `bundle install` to lock versions into `Gemfile.lock`.

Tag pages (per-tag listing of posts) are generated with a plain Liquid
`{% for %}` loop over `site.tags` in an include, not a plugin — the common
plugin for this (`jekyll-tagsgenerator`) hasn't been maintained since ~2018,
and Jekyll's built-in `site.tags` data is enough to build tag pages without
it.

## PDF.js (vendored, not a gem)

The in-browser PDF viewer (see `milestones.md`, M4) is Mozilla's PDF.js,
vendored directly into the repo as static files rather than pulled in via a
package manager — GitHub Pages just serves it like any other asset.

```bash
# fetch the latest "generic" prebuilt release
curl -L -o /tmp/pdfjs.zip \
  https://github.com/mozilla/pdf.js/releases/latest/download/pdfjs-<version>-dist.zip

# unzip into the repo
unzip /tmp/pdfjs.zip -d assets/pdfjs
```

(Check https://github.com/mozilla/pdf.js/releases for the current version
number to substitute into the URL — "latest" redirects don't resolve the
asset filename, which is version-stamped.)

Each PDF post's layout points an iframe at the vendored viewer:

```html
<iframe src="/assets/pdfjs/web/viewer.html?file={{ page.pdf }}"
        width="100%" height="800"></iframe>
```

**Updating:** re-download a newer release and overwrite `assets/pdfjs/`
periodically for bugfixes/security patches — there's no automatic update
mechanism since it isn't managed by Bundler/npm.

## Adding a new post

Each post pairs one PDF with a `_posts/` markdown file. Use the scaffolding
script rather than creating both by hand — it keeps the PDF path, front
matter, and file naming in sync:

```bash
ruby script/new_post.rb "Title Of The Note" \
  --topic calculus \
  --pdf ~/scans/notes.pdf \
  --tags "midterm-review,chapter-3"   # optional
  --date 2026-07-15                   # optional, defaults to today
```

This:
1. Copies the source PDF to `assets/pdfs/<topic>/<date>-<slug>.pdf`
   (creating the topic folder if it's new).
2. Creates `_posts/<date>-<slug>.md` with front matter filled in
   (`layout: pdf-post`, `title`, `date`, `category`, `tags`, `pdf`).
3. Leaves a placeholder in the post body for context text — write normal
   Markdown here; it renders above the embedded PDF viewer on the page.

**Topic hierarchy:** `--topic` is the post's primary category and doubles
as the folder PDFs are organized under (`assets/pdfs/<topic>/`), so the
repo's file layout mirrors the site's topic structure — browsable on disk,
not just through generated tag/category pages. Use `--tags` for anything
that cuts across topics instead of inventing a new topic per label.

**Manual equivalent**, if you'd rather not run the script: place the PDF
at `assets/pdfs/<topic>/<date>-<slug>.pdf`, create
`_posts/<date>-<slug>.md` with the same front matter fields by hand, and
write the front matter's `pdf:` path to match exactly where you put the
file.

## GitHub Actions deploy workflow

`.github/workflows/deploy.yml` (to be added in M1) builds with Bundler and
deploys the `_site/` output using GitHub's official Pages actions:

- `actions/checkout`
- `ruby/setup-ruby` (with `bundler-cache: true`)
- `bundle exec jekyll build`
- `actions/upload-pages-artifact`
- `actions/deploy-pages`

This runs on every push to `main`, so no local build/deploy step is needed
day-to-day — `bundle exec jekyll serve` locally is just for previewing.
