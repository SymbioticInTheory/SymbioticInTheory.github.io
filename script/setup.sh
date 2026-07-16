#!/usr/bin/env bash
# Installs the dev environment prerequisites documented in
# docs/DEVELOPMENT.md: apt build deps, rbenv + ruby-build, a project-scoped
# Ruby, and a project-local Bundler gem path. Safe to re-run — each step
# checks whether it's already satisfied before acting.
set -euo pipefail

RUBY_VERSION="3.4.10"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

info() { printf '\033[1;34m[info]\033[0m %s\n' "$1"; }
ok()   { printf '\033[1;32m[ok]\033[0m   %s\n' "$1"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

# Make an already-installed rbenv usable in this shell, whether we're about
# to install things or just running --check — without this, `have rbenv`
# fails even when ~/.rbenv exists, because rbenv only lands on PATH via
# ~/.bashrc, which a non-interactive script invocation never sources.
load_rbenv_env() {
  if [ -d "$HOME/.rbenv" ]; then
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init - bash)"
  fi
}

# ---------------------------------------------------------------------------
# 1. apt build dependencies (needed for ruby-build to compile Ruby)
# ---------------------------------------------------------------------------
install_apt_deps() {
  if ! have apt; then
    warn "apt not found — skipping system package install. Install these" \
         "manually via your distro's package manager: git curl build-essential" \
         "libssl-dev libreadline-dev zlib1g-dev autoconf bison libyaml-dev" \
         "libncurses5-dev libffi-dev libgdbm-dev unzip"
    return
  fi
  info "Installing apt build dependencies (sudo required)..."
  sudo apt update
  sudo apt install -y git curl build-essential libssl-dev libreadline-dev \
    zlib1g-dev autoconf bison libyaml-dev libncurses5-dev libffi-dev \
    libgdbm-dev unzip
}

# ---------------------------------------------------------------------------
# 2. rbenv + ruby-build
# ---------------------------------------------------------------------------
install_rbenv() {
  if [ -d "$HOME/.rbenv" ]; then
    ok "rbenv already installed at $HOME/.rbenv"
  else
    info "Cloning rbenv..."
    git clone https://github.com/rbenv/rbenv.git "$HOME/.rbenv"
  fi

  local bashrc="$HOME/.bashrc"
  grep -qxF 'export PATH="$HOME/.rbenv/bin:$PATH"' "$bashrc" 2>/dev/null || \
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> "$bashrc"
  grep -qxF 'eval "$(rbenv init - bash)"' "$bashrc" 2>/dev/null || \
    echo 'eval "$(rbenv init - bash)"' >> "$bashrc"

  load_rbenv_env

  if [ -d "$HOME/.rbenv/plugins/ruby-build" ]; then
    ok "ruby-build already installed"
  else
    info "Cloning ruby-build plugin..."
    git clone https://github.com/rbenv/ruby-build.git "$HOME/.rbenv/plugins/ruby-build"
  fi
}

# ---------------------------------------------------------------------------
# 3. Ruby, scoped to this repo
# ---------------------------------------------------------------------------
install_ruby() {
  if rbenv versions --bare | grep -qx "$RUBY_VERSION"; then
    ok "Ruby $RUBY_VERSION already installed via rbenv"
  else
    info "Installing Ruby $RUBY_VERSION via rbenv (this compiles from source, ~a few minutes)..."
    rbenv install "$RUBY_VERSION"
  fi

  (cd "$REPO_ROOT" && rbenv local "$RUBY_VERSION")
  ok "Repo scoped to Ruby $RUBY_VERSION (.ruby-version written)"
}

# ---------------------------------------------------------------------------
# 4. Bundler, into a project-local gem path
# ---------------------------------------------------------------------------
install_bundler() {
  (
    cd "$REPO_ROOT"
    if rbenv exec gem list -i bundler >/dev/null 2>&1; then
      ok "Bundler already installed"
    else
      info "Installing Bundler..."
      rbenv exec gem install bundler
    fi
    rbenv exec bundle config set --local path 'vendor/bundle'
    ok "Bundler configured to install gems into ./vendor/bundle"
  )
}

# ---------------------------------------------------------------------------
# Compatibility check — reports current state, doesn't install anything
# ---------------------------------------------------------------------------
check_environment() {
  local missing=()

  echo
  info "Compatibility check:"

  if have apt; then
    ok "apt available"
  else
    warn "apt not found (not a concern outside Ubuntu/Debian, but the" \
         "install steps above assume it)"
  fi

  if [ -d "$HOME/.rbenv" ] && have rbenv; then
    ok "rbenv installed"
  else
    warn "rbenv not installed"
    missing+=("rbenv")
  fi

  if [ -d "$HOME/.rbenv/plugins/ruby-build" ]; then
    ok "ruby-build installed"
  else
    warn "ruby-build not installed"
    missing+=("ruby-build")
  fi

  if have rbenv && rbenv versions --bare 2>/dev/null | grep -qx "$RUBY_VERSION"; then
    ok "Ruby $RUBY_VERSION installed"
  else
    warn "Ruby $RUBY_VERSION not installed"
    missing+=("ruby-$RUBY_VERSION")
  fi

  if [ -f "$REPO_ROOT/.ruby-version" ] && \
     [ "$(cat "$REPO_ROOT/.ruby-version")" = "$RUBY_VERSION" ]; then
    ok "Repo scoped to Ruby $RUBY_VERSION (.ruby-version)"
  else
    warn "Repo not scoped to Ruby $RUBY_VERSION"
    missing+=("rbenv-local")
  fi

  if have rbenv && (cd "$REPO_ROOT" && rbenv exec gem list -i bundler >/dev/null 2>&1); then
    ok "Bundler installed"
  else
    warn "Bundler not installed"
    missing+=("bundler")
  fi

  if [ -f "$REPO_ROOT/Gemfile" ]; then
    ok "Gemfile present"
  else
    warn "No Gemfile yet — this repo is pre-M1 scaffold (see milestones.md)." \
         "That's expected right now and isn't something this script fixes;" \
         "'bundle install' will have nothing to install until the Jekyll" \
         "scaffold (Gemfile, _config.yml, etc.) lands."
  fi

  echo
  if [ "${#missing[@]}" -eq 0 ]; then
    ok "Environment is good to go. Once a Gemfile exists, run 'bundle install' from the repo root."
  else
    warn "Environment is NOT fully ready. Missing: ${missing[*]}"
    warn "Re-run this script (./script/setup.sh) to install the missing pieces, or run it with no arguments to install everything."
  fi
}

# ---------------------------------------------------------------------------
main() {
  load_rbenv_env

  if [ "${1:-}" = "--check" ]; then
    check_environment
    exit 0
  fi

  install_apt_deps
  install_rbenv
  install_ruby
  install_bundler
  check_environment
}

main "$@"
