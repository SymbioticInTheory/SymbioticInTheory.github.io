# Developer Setup & Dependencies

This project is a static Jekyll site deployed to GitHub Pages via a custom
GitHub Actions workflow (not the native Pages Jekyll build), which is what
lets us use plugins outside GitHub's built-in plugin whitelist.

If you're here to add or edit a post, you almost certainly don't need
most of this document — start with the next section. The full local
development environment (further down) is only needed to preview the
site locally before pushing; everything about writing and organizing
posts works without it.

## Adding a post from a lightweight machine (no dev setup)

Everything under "Local development environment" (further down this
document — `rbenv`, Bundler, the Jekyll gem, `vendor/bundle`) exists only
so you can *preview the site locally* before pushing. The actual site
build and deploy happens automatically on GitHub's servers (see
`docs/GITHUB_ACTIONS.md`) every time you push to `main` — so a smaller
machine that can just edit text, organize files, and run one Ruby script
is enough to add real posts.

### What that machine actually needs

- **Ruby** — any reasonably modern version (3.x). It does *not* need to
  match the exact pinned `3.4.10`, and it does not need `rbenv` — the
  scaffolding scripts (`script/new_post.rb`, `script/edit_post.rb`) only
  use Ruby's built-in standard library, no gems, so there's nothing to
  `bundle install`.
- **git** — to save your new post and PDF and send them to GitHub.
- **`pdftoppm`** (from the `poppler-utils` package) — optional. It's what
  generates the little cover-image thumbnail for the homepage. Skip it
  and the post still works fine; it just falls back to a plain placeholder
  icon on the homepage instead of a picture of the note's first page.
- A plain text editor (anything — Notepad, TextEdit, VS Code, `nano`,
  whatever's on hand).

On a fresh Ubuntu/Debian machine, that's just:

```bash
sudo apt update
sudo apt install -y ruby-full git poppler-utils
```

(`ruby-full` rather than bare `ruby` — Debian/Ubuntu sometimes splits
parts of Ruby's standard library into separate packages, and `ruby-full`
avoids having to figure out which ones; it's still a much smaller ask
than the full rbenv toolchain used to compile a pinned Ruby version from
source.)

You do **not** need to run `script/setup.sh`, install `rbenv`, or run
`bundle install` on this machine. You also won't be able to run
`bundle exec jekyll serve` to preview locally — see step 6 below for what
to do instead.

### Step-by-step: adding a new post

This walks through the whole process end to end, assuming no prior
experience with this project's tooling.

**1. Get the project folder onto the machine (only once, the first time).**

If it's not already there:

```bash
git clone git@github.com:SymbioticInTheory/SymbioticInTheory.github.io.git
cd SymbioticInTheory.github.io
```

If it's already there from before, just make sure it's up to date:

```bash
cd SymbioticInTheory.github.io
git pull
```

**2. Have your PDF ready somewhere on the machine (skip this if the post
doesn't need one — see step 4).**

It doesn't need to be inside the project folder — anywhere is fine (your
Downloads folder, Desktop, a USB drive, wherever). The script copies it
into the right place for you; you just need to know the file's path,
e.g. `~/Downloads/chem-lab-3.pdf`.

**3. Decide three things before you type the command:**

- **Title** — plain English, whatever you'd want as the post's heading.
  E.g. `"Lab Notebook, Week 3"`.
- **Topic** — think of this as which *folder/shelf* the note belongs on.
  It becomes part of the file path (`assets/pdfs/<topic>/`) and the post's
  URL. Look at `assets/pdfs/` to see topics already in use (e.g.
  `journal`) — reuse one of those if it fits, or invent a new one if it
  doesn't; the folder gets created automatically. Pick one topic per post.
- **Tags** (optional) — unlike topic, a post can have *several* tags, and
  tags are for labels that cut *across* topics rather than defining a new
  shelf of their own. Example: a `midterm-review` tag could apply to notes
  from several different topics/classes, so it's a tag, not a topic.

**4. Run the scaffolding script.**

From inside the project folder:

```bash
ruby script/new_post.rb "Lab Notebook, Week 3" \
  --topic chemistry \
  --pdf ~/Downloads/chem-lab-3.pdf \
  --tags "lab-notes,week-3"
```

Leave off `--pdf` entirely for a text-only post (no scanned note, just
writing) — everything else about the process is the same, just without
the PDF/cover files and the embedded viewer. Leave off `--tags` if this
post doesn't need any. There's also an optional `--date 2026-07-15` if
you want a date other than today.

With a PDF, you'll see output like:

```
Created post:  _posts/2026-07-16-lab-notebook-week-3.md
Copied PDF to: assets/pdfs/chemistry/2026-07-16-lab-notebook-week-3.pdf
Cover image:   assets/pdfs/chemistry/2026-07-16-lab-notebook-week-3.png
```

Three new files now exist in the project folder — a text file (the post)
and two copies related to your PDF (the PDF itself, and a small preview
image of its first page). You don't need to touch the PDF or image
files again; everything from here happens in the text file.

(Without `--pdf`, you'll just see `Created post: ...` and a note that
it's a text-only post — there's no PDF or cover image to copy, just the
one file.)

**5. Open the new post file in your text editor and add context text.**

The file is at the path printed above, e.g.
`_posts/2026-07-16-lab-notebook-week-3.md`. Open it in whatever text
editor you like. You'll see something like this at the top — **don't
edit this part**, the script already filled it in correctly:

```
---
layout: pdf-post
title: "Lab Notebook, Week 3"
date: 2026-07-16
category: chemistry
tags: [lab-notes, week-3]
pdf: /assets/pdfs/chemistry/2026-07-16-lab-notebook-week-3.pdf
cover: /assets/pdfs/chemistry/2026-07-16-lab-notebook-week-3.png
---
```

(Without `--pdf`, this block is shorter — `layout: post` instead of
`layout: pdf-post`, and no `pdf:`/`cover:` lines.)

Below that block is a placeholder comment. Delete it and replace it with
a few sentences of plain English describing the note — this text appears
on the page above the embedded PDF (or, for a text-only post, it's simply
the whole page). It's normal writing; you don't need to know any special
syntax, though a few things work if you want them:

- A blank line between paragraphs starts a new paragraph.
- `**word**` makes a **word** bold.
- A line starting with `- ` makes a bullet point.

That's it — save the file when you're happy with it.

**6. Preview it (optional — only if this machine has the full dev setup).**

If this is a lightweight machine, you likely can't run
`bundle exec jekyll serve` (that needs the full setup further down this
doc). That's fine — skip straight to step 7 and check the *live* site a
minute or two after pushing instead of previewing locally first.

**7. Save your work and send it to GitHub.**

```bash
git add _posts assets/pdfs
git commit -m "Add Lab Notebook, Week 3"
git push
```

(`git add _posts assets/pdfs` stages both the new post file and the new
PDF/cover-image files — the two folders where `script/new_post.rb` put
everything.)

**8. Wait about a minute, then check the live site.**

Pushing to `main` automatically kicks off a build-and-deploy on GitHub's
servers (see `docs/GITHUB_ACTIONS.md` if you want the details) — nothing
further to run yourself. Visit https://symbioticintheory.github.io/ and
your new post should be there. If something looks wrong, go to the
**Actions** tab on GitHub to see whether the build failed and why (most
often a typo in the front matter block from step 5).

**Made a mistake?** For small things — a typo, a missing sentence — just
open the same `_posts/....md` file again, fix it, and repeat step 7
(`git add`, `git commit`, `git push`). For fixing tags or moving a post
to a different topic, use `script/edit_post.rb` instead of hand-editing —
see "Editing an existing post" below; it's the same kind of script as
`new_post.rb` and works on this same lightweight machine.

## Adding a new post (quick reference)

The condensed version of the walkthrough above, for anyone who already
knows this project's conventions:

```bash
ruby script/new_post.rb "Title Of The Note" \
  --topic calculus \
  --pdf ~/scans/notes.pdf \
  --tags "midterm-review,chapter-3" \
  --date 2026-07-15
```

(`--pdf`, `--tags`, and `--date` are all optional — omit `--pdf` entirely
for a text-only post; `--date` defaults to today if left off.)

This:
1. If `--pdf` was given, copies the source PDF to
   `assets/pdfs/<topic>/<date>-<slug>.pdf` (creating the topic folder if
   it's new).
2. If `--pdf` was given, renders page 1 of the PDF to a cover thumbnail,
   `assets/pdfs/<topic>/<date>-<slug>.png`, via `pdftoppm` (poppler-utils
   — see "Local development environment" below) — shown next to the post
   in the homepage feed (M5) instead of a generic placeholder. If
   `pdftoppm` isn't installed, the script warns and continues without a
   cover rather than aborting; the feed just falls back to a placeholder
   for that post.
3. Creates `_posts/<date>-<slug>.md` with front matter filled in. With
   `--pdf`: `layout: pdf-post`, `title`, `date`, `category`, `tags`,
   `pdf`, and `cover` if a thumbnail was generated. Without `--pdf`:
   `layout: post` and just `title`, `date`, `category`, `tags` — a
   text-only post, same as the ones used to test the homepage feed
   during M2.
4. Leaves a placeholder in the post body for context text — write normal
   Markdown here. With `--pdf` it renders above the embedded PDF viewer;
   without it, it's simply the whole post.

**Topic hierarchy:** `--topic` is the post's primary category and, for
PDF posts, also doubles as the folder PDFs are organized under
(`assets/pdfs/<topic>/`), so the repo's file layout mirrors the site's
topic structure — browsable on disk, not just through generated
tag/category pages. Text-only posts don't have a PDF to organize on disk,
so `--topic` for those is just the `category:` front-matter value. Use
`--tags` for anything that cuts across topics instead of inventing a new
topic per label.

**Manual equivalent**, if you'd rather not run the script: for a PDF
post, place the PDF at `assets/pdfs/<topic>/<date>-<slug>.pdf`, create
`_posts/<date>-<slug>.md` with the same front matter fields by hand
(`layout: pdf-post`), and write the front matter's `pdf:` path to match
exactly where you put the file. For a cover thumbnail, run
`pdftoppm -png -singlefile -f 1 -l 1 -scale-to 600 <pdf> <pdf-without-extension>`
and add a matching `cover:` front-matter field — both optional. For a
text-only post, just create `_posts/<date>-<slug>.md` with
`layout: post` and no `pdf:`/`cover:` fields.

## Editing an existing post

`script/edit_post.rb` changes an already-published post's tags, title, or
topic, without you needing to hand-edit front matter or move PDF files
around yourself. Same deal as `new_post.rb` — zero gem dependencies, so it
works on the lightweight machine described above just as well as on a
full dev setup:

```bash
ruby script/edit_post.rb _posts/2026-07-16-lab-notebook-week-3.md \
  --tags "lab-notes,week-4" \
  --title "Lab Notebook, Week 4" \
  --topic biology
```

Pass any combination of `--tags`, `--title`, `--topic` — only what you
pass gets changed. Your context text (the post body) is never touched.

- **`--tags "a,b"`** replaces the post's tag list outright. Pass an empty
  string (`--tags ""`) to clear all tags.
- **`--title "New Title"`** only changes the displayed title — it does
  not rename the post's file, change its date, or change its URL.
- **`--topic new-topic`** *reorganizes* the post: if it has a PDF, the
  script moves the PDF (and its cover thumbnail, if it has one) into
  `assets/pdfs/<new-topic>/` and updates the front matter to match — the
  same layout `new_post.rb` would have created in the first place.
  **This changes the post's URL**, since the permalink includes its
  topic/category — the script prints a reminder when this happens. Posts
  with no PDF (plain text posts) just get relabeled; there's nothing on
  disk to move for those.

Save and publish the change the same way as any other:

```bash
git add _posts assets/pdfs
git commit -m "Move Lab Notebook, Week 4 to biology"
git push
```

**Not covered by the script:** changing a post's date, or renaming its
file/URL slug. Both still need to be done by hand — edit the front
matter's `date:` field and rename the `_posts/...` file and its paired
PDF/cover files to match, keeping the `<date>-<slug>` pattern consistent
across all three.

## Local development environment

The rest of this document covers running the site locally — building it
yourself and previewing it at `http://localhost:4000` before pushing.
None of it is required just to add or edit posts (see above).

### Prerequisites

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
  zlib1g-dev autoconf bison libyaml-dev libncurses5-dev libffi-dev libgdbm-dev \
  unzip poppler-utils
# (unzip is also used later for vendoring PDF.js, see below; poppler-utils
# provides pdftoppm, used by script/new_post.rb to generate cover thumbnails)

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

### Installing the project

```bash
bundle install       # installs Jekyll + all plugins from the Gemfile
bundle exec jekyll serve   # local dev server at http://localhost:4000
bundle exec jekyll build   # one-off static build into _site/
```

### Gemfile plugins

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

### PDF.js (vendored, not a gem)

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
