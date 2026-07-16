# Developer Setup & Dependencies

This project is a static Jekyll site deployed to GitHub Pages via a custom
GitHub Actions workflow (not the native Pages Jekyll build), which is what
lets us use plugins outside GitHub's built-in plugin whitelist.

## Prerequisites

- Ruby (3.x) and Bundler

Ruby 3.0+ removed `webrick` from the standard library, and Jekyll's local
dev server depends on it, so it's listed explicitly in the Gemfile below.

Run `script/setup.sh` to perform all of the steps below in one shot — it's
idempotent (safe to re-run) and skips anything already installed. Run
`script/setup.sh --check` on its own to just report environment status
without installing anything. The manual steps are documented below for
reference / in case you'd rather run them by hand.

### System setup (Ubuntu/Debian)

Ubuntu's apt-provided Ruby lags well behind 3.x (e.g. 20.04 ships 2.7), so
install Ruby via **rbenv** instead of `apt install ruby-full` — it's the
virtualenv-equivalent for Ruby: a project-scoped interpreter version with
no sudo needed after the initial toolchain setup. Gems then go into a
project-local Bundler path, the equivalent of a venv for gems, instead of
a global gem install.

```bash
# 1. build toolchain rbenv/ruby-build need to compile Ruby from source
sudo apt update
sudo apt install -y git curl build-essential libssl-dev libreadline-dev \
  zlib1g-dev autoconf bison libyaml-dev libncurses5-dev libffi-dev libgdbm-dev unzip
# (unzip is also used later for vendoring PDF.js, see below)

# 2. rbenv + ruby-build
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
# (older guides say to also run `cd ~/.rbenv && src/configure && make -C src`
# here to build an optional speedup extension — current rbenv versions build
# it automatically and print a deprecation notice if you run it manually, so
# it's skipped here)

echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init - bash)"' >> ~/.bashrc
source ~/.bashrc

git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

# 3. install a Ruby 3.x and scope it to this repo
rbenv install -l | tail        # see latest available versions
rbenv install 3.4.10           # newest stable 3.x; avoid 4.x until the gem
                                # ecosystem (native extensions especially)
                                # has caught up to the new major version

cd /path/to/SymbioticInTheory.github.io
rbenv local 3.4.10             # writes .ruby-version, scopes this dir to that Ruby

# 4. Bundler, installed into the project-local gem path (not global)
gem install bundler
bundle config set --local path 'vendor/bundle'   # gems land in ./vendor/bundle
```

Verify:

```bash
ruby -v      # should show the rbenv-installed 3.x, not the system Ruby
gem -v
```

### GitHub CLI (`gh`)

Not required to build or serve the site, but useful for working with this
repo's GitHub side (checking Actions run status/logs, PRs, issues) without
leaving the terminal — see `docs/GITHUB_ACTIONS.md`.

Ubuntu's default apt repos predate GitHub adding `gh` as a package there,
so `apt install gh` fails with "unable to locate package" out of the box.
Install from GitHub's own apt repository instead (their documented method,
not a workaround):

```bash
(type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
	&& sudo mkdir -p -m 755 /etc/apt/keyrings \
	&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& sudo mkdir -p -m 755 /etc/apt/sources.list.d \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& sudo apt update \
	&& sudo apt install gh -y
```

Verify:

```bash
gh --version
gh auth login    # one-time, needed before gh can act on your behalf
```

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
