# GitHub Actions

This project uses GitHub Actions to build and deploy the site. If you
haven't used Actions before, this doc explains it using the workflow
already running in this repo (`.github/workflows/deploy.yml`) as the
example, then covers what else it's capable of.

## What it is

GitHub Actions is CI/CD (continuous integration / continuous deployment)
built into GitHub itself — no external service (Netlify, CircleCI,
Jenkins) required. You describe a **workflow** as a YAML file committed to
`.github/workflows/`, and GitHub runs it on its own servers whenever a
trigger you specify fires: a push, a pull request, on a schedule, or a
manual button click.

Concretely: every file in `.github/workflows/*.yml` is one workflow.
This repo has one, `deploy.yml`, which builds the Jekyll site and
publishes it to GitHub Pages.

## Why this project needs it at all

GitHub Pages can build a Jekyll site for you automatically, with zero
Actions involved — but only using a fixed, small whitelist of plugins. As
noted in `CLAUDE.md`, that's the architecture decision behind using
Actions here: a custom workflow builds the site ourselves with whatever
Gemfile we want (see `jekyll-seo-tag`, `jekyll-sitemap`, etc. in the
Gemfile), then hands GitHub only the finished static output to publish.
Actions is the mechanism that makes "build it our way, deploy it their
way" possible.

## Anatomy of `deploy.yml`

```yaml
on:
  push:
    branches: ["main"]
  workflow_dispatch:
```

The **trigger**. This workflow runs automatically on every push to
`main`, and `workflow_dispatch` adds a manual "Run workflow" button on the
workflow's page in the Actions tab — useful for re-running a deploy
without needing an empty commit.

```yaml
permissions:
  contents: read
  pages: write
  id-token: write
```

Workflows get *no* permissions by default beyond what you grant. This one
needs to read the repo's contents (to build it), write to Pages (to
publish), and issue an OIDC token (`id-token`) — that last one is what
lets `actions/deploy-pages` authenticate as "this specific workflow run"
without a stored secret/password.

```yaml
concurrency:
  group: "pages"
  cancel-in-progress: false
```

If you push twice in quick succession, this queues the second deploy
behind the first instead of letting two deploys race each other and
possibly publish out of order.

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps: ...
  deploy:
    runs-on: ubuntu-latest
    needs: build
    steps: ...
```

A workflow is made of **jobs**; each job runs on a fresh virtual machine
(`runs-on: ubuntu-latest` — a clean throwaway Ubuntu container, not your
machine or GitHub's "production" anything). Jobs run in parallel by
default; `needs: build` forces `deploy` to wait until `build` finishes
successfully. Splitting build/deploy into two jobs here mirrors GitHub's
own recommended Pages pattern and keeps the "produce the site" step
cleanly separated from the "publish it" step.

Within a job, **steps** run in order, top to bottom, on that same VM.
Each step is either:
- `run: <shell command>` — just runs a shell command, or
- `uses: <action>@<version>` — invokes a pre-built, reusable **action**
  (a packaged unit of automation, versioned and shared, similar in spirit
  to installing a library rather than writing the logic yourself)

Walking through `build`'s steps: `actions/checkout` clones this repo onto
the runner; `ruby/setup-ruby` installs Ruby 3.4 and — thanks to
`bundler-cache: true` — caches `vendor/bundle` between runs so it doesn't
reinstall every gem on every push; `actions/configure-pages` figures out
the right base URL/settings for Pages; then a plain `run:` step does the
actual `bundle exec jekyll build`; `actions/upload-pages-artifact`
packages the resulting `_site/` directory as a build artifact for the next
job to pick up.

`deploy`'s one step, `actions/deploy-pages`, takes that artifact and
publishes it live. The `environment:` block is what makes the deployment
show up as a tracked "Deployment" in the repo's sidebar, with a direct
link to the live URL.

## Where to look things up

- **Actions tab** (top nav of the repo) — every run, past and present,
  with full logs per step. This is where you go when a build fails.
- **Actions tab → workflow name in the left sidebar** — that workflow's
  own page; this is where the manual "Run workflow" button lives (it's
  not on the tab's landing page).
- **Settings → Pages** — confirms the deployment source is "GitHub
  Actions" (not "Deploy from a branch") and shows the live URL.

## What else Actions can do (beyond what we use today)

The deploy workflow only scratches the surface. Things worth knowing
Actions *could* do for this project later, without needing new
infrastructure:

- **Run on pull requests, not just pushes** — e.g. build the site on every
  PR to catch a broken Liquid tag or bad front matter before it merges,
  without deploying it.
- **More steps per job** — nothing stops adding a link-checker, an HTML
  validator, or a spellchecker as extra steps before the deploy step, so
  a broken build fails loudly instead of silently shipping.
- **Scheduled runs** (`on: schedule`, cron syntax) — e.g. a periodic job
  that checks for a new PDF.js release and opens a PR, instead of the
  manual "re-download and overwrite `assets/pdfjs/`" process documented in
  `DEVELOPMENT.md`.
- **Matrix builds** — run the same job multiple times with different
  inputs in parallel (e.g. multiple Ruby versions) — overkill for a
  single-Gemfile blog, but the mechanism exists.
- **Secrets** (Settings → Secrets and variables → Actions) — encrypted
  values injected into a workflow at runtime (API keys, tokens) without
  ever appearing in the repo. Not needed yet since Pages deploy auths via
  the OIDC token, but this is how you'd add e.g. a third-party analytics
  or notification integration later.
- **The Marketplace** — `uses: owner/action@version` can point at
  virtually any public GitHub repo packaging an action, not just
  `actions/*` ones. The four actions used in `deploy.yml` are official
  GitHub ones; there's a much larger ecosystem of community actions for
  almost anything (image optimization, deploying elsewhere, posting to
  Slack, etc.).

None of the above is implemented — this section is a map of what's
available, not a to-do list.
