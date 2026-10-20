#!/usr/bin/env bash
#
# verify.sh: check a student's MIS 58710 Week 1 setup.
#
# Usage (from your home folder):
#   gh repo clone mis-devops-purdue/verify-setup
#   bash verify-setup/verify.sh
#
# This script is READ-ONLY. It never installs, changes, or deletes anything,
# and it never uses sudo. It runs version and status commands and reports
# what it finds.
#
# Written for bash 3.2 (the version macOS ships), so: no associative arrays,
# no mapfile, no ${var,,}.

set -u

GUIDE="https://mis-devops-purdue.github.io/setup-guide"

PASS=0
FAIL=0
WARN=0

GH_USER="(not signed in)"
GCLOUD_ACCOUNT="(not signed in)"

# --- Output helpers ---------------------------------------------------------

section() {
  printf '\n%s\n' "$1"
}

pass() {
  PASS=$((PASS + 1))
  printf '  ✅ %s\n' "$1"
}

# fail "what failed" "how to fix it" "guide page"
fail() {
  FAIL=$((FAIL + 1))
  printf '  ❌ %s\n' "$1"
  printf '     Fix: %s\n' "$2"
  printf '     See: %s\n' "$3"
}

# warn "what looks wrong" "how to fix it" "guide page"
warn() {
  WARN=$((WARN + 1))
  printf '  ⚠️  %s\n' "$1"
  printf '     Fix: %s\n' "$2"
  printf '     See: %s\n' "$3"
}

skip() {
  printf '  ➖ %s (not needed on %s)\n' "$1" "$PLATFORM_NAME"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

# page <slug>: URL of a page in the current platform's part of the guide.
page() {
  printf '%s/%s/%s/' "$GUIDE" "$PART" "$1"
}

# --- Platform detection -----------------------------------------------------

PLATFORM=""
if [ "${CLOUD_SHELL:-}" = "true" ]; then
  PLATFORM="cloudshell"
elif [ "$(uname -s)" = "Darwin" ]; then
  PLATFORM="mac"
elif grep -qi microsoft /proc/version 2>/dev/null; then
  PLATFORM="wsl"
else
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*) PLATFORM="windows-native" ;;
    Linux) PLATFORM="linux" ;;
    *) PLATFORM="unknown" ;;
  esac
fi

case "$PLATFORM" in
  cloudshell) PLATFORM_NAME="GCP Cloud Shell"; PART="cloud-shell" ;;
  mac) PLATFORM_NAME="macOS"; PART="mac" ;;
  wsl) PLATFORM_NAME="Windows (WSL)"; PART="windows" ;;
  linux) PLATFORM_NAME="Linux (not WSL or Cloud Shell)"; PART="windows" ;;
  *) PLATFORM_NAME="unknown"; PART="windows" ;;
esac

printf '\nMIS 58710 setup check\n'
printf 'This script only reads your setup. It changes nothing.\n'

section "Platform"
case "$PLATFORM" in
  windows-native)
    printf '  ❌ You are running this on Windows, outside WSL (for example in Git Bash).\n'
    printf '     Fix: Open the Ubuntu app and run the script there:\n'
    printf '          cd ~ && gh repo clone mis-devops-purdue/verify-setup && bash verify-setup/verify.sh\n'
    printf '     See: %s/windows/install-wsl/\n\n' "$GUIDE"
    exit 1
    ;;
  unknown)
    printf '  ❌ Unrecognized system: %s\n' "$(uname -s)"
    printf '     This script supports Windows (WSL), macOS, and GCP Cloud Shell.\n'
    printf '     See: %s/choose-your-path/\n\n' "$GUIDE"
    exit 1
    ;;
  linux)
    warn "Running on plain Linux, not WSL or Cloud Shell. Checking it like WSL." \
      "If you're on Windows, run this from the Ubuntu app." \
      "$GUIDE/choose-your-path/"
    ;;
  *)
    pass "Detected $PLATFORM_NAME"
    ;;
esac

if [ "$PLATFORM" = "wsl" ]; then
  case "$PWD" in
    /mnt/*)
      warn "Current folder is on the Windows drive ($PWD)" \
        "Run 'cd ~' and keep your projects under ~/projects, not under /mnt/c." \
        "$GUIDE/windows/before-you-start/"
      ;;
    *)
      pass "Current folder is in your Linux home, not under /mnt/c"
      ;;
  esac
fi

# --- Git --------------------------------------------------------------------

section "Git"
if have git; then
  pass "git installed ($(git --version 2>/dev/null | sed 's/^git version //'))"

  git_name=$(git config --global user.name 2>/dev/null || true)
  if [ -n "$git_name" ]; then
    pass "user.name is set ($git_name)"
  else
    fail "user.name is not set" \
      "git config --global user.name \"Your Name\"" \
      "$(page git-and-github)"
  fi

  git_email=$(git config --global user.email 2>/dev/null || true)
  if [ -n "$git_email" ]; then
    pass "user.email is set ($git_email)"
  else
    fail "user.email is not set" \
      "git config --global user.email \"you@example.com\" (the email on your GitHub account)" \
      "$(page git-and-github)"
  fi
else
  fail "git is not installed" \
    "Install Git (page 2 of your part of the guide)." \
    "$(page git-and-github)"
fi

# --- GitHub CLI -------------------------------------------------------------

section "GitHub CLI"
if have gh; then
  pass "gh installed ($(gh --version 2>/dev/null | head -n 1 | sed -e 's/^gh version //' -e 's/ (.*//'))"

  if gh auth status --hostname github.com >/dev/null 2>&1; then
    login=$(gh api user --jq .login 2>/dev/null || true)
    if [ -n "$login" ]; then
      GH_USER="$login"
    else
      GH_USER="(signed in, username unavailable)"
    fi
    pass "gh is signed in to GitHub ($GH_USER)"
  else
    fail "gh is not signed in to GitHub" \
      "gh auth login --hostname github.com --git-protocol https --web" \
      "$(page git-and-github)"
  fi
else
  fail "gh is not installed" \
    "Install the GitHub CLI (page 2 of your part of the guide)." \
    "$(page git-and-github)"
fi

# --- Python, pipx, Poetry ---------------------------------------------------

section "Python and Poetry"
if have python3; then
  py_version=$(python3 -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])' 2>/dev/null || echo "unknown")
  if python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' >/dev/null 2>&1; then
    pass "python3 is $py_version (3.11 or newer)"
  else
    if [ "$PLATFORM" = "mac" ]; then
      py_fix="brew install python, then close and reopen Terminal. 'which python3' should not be /usr/bin/python3."
    else
      py_fix="You need Python 3.11 or newer. See the troubleshooting page."
    fi
    fail "python3 is $py_version (need 3.11 or newer)" "$py_fix" "$GUIDE/troubleshooting/"
  fi
else
  fail "python3 is not installed" \
    "Install Python (page 3 of your part of the guide)." \
    "$(page python-and-poetry)"
fi

if [ "$PLATFORM" = "cloudshell" ]; then
  skip "pipx"
else
  if have pipx; then
    pass "pipx is on your PATH"
  else
    fail "pipx is not on your PATH" \
      "Install pipx, run 'pipx ensurepath', then close and reopen your terminal." \
      "$(page python-and-poetry)"
  fi
fi

if have poetry; then
  # Run Poetry from / so a pyproject.toml in the current folder can't change
  # the result (or make Poetry install project plugins).
  poetry_version=$(cd / && poetry --version 2>/dev/null | sed -n 's/.*version \([0-9][0-9.]*\).*/\1/p' | head -n 1)
  poetry_major=${poetry_version%%.*}
  case "$poetry_major" in
    '' | *[!0-9]*) poetry_major=0 ;;
  esac
  if [ "$poetry_major" -ge 2 ]; then
    pass "poetry is $poetry_version (2.0 or newer)"
  else
    fail "poetry is ${poetry_version:-unknown} (need 2.0 or newer)" \
      "Reinstall Poetry following page 3 of your part of the guide." \
      "$(page python-and-poetry)"
  fi

  if (cd / && poetry export --help >/dev/null 2>&1); then
    pass "Poetry export plugin is installed"
  else
    export_problem="Poetry export plugin is missing"
    if [ "$PLATFORM" = "cloudshell" ]; then
      export_fix="poetry self add poetry-plugin-export"
    else
      export_fix="pipx inject poetry poetry-plugin-export"

      # With two Poetry installs (often Homebrew's ahead of pipx's), the first
      # one on PATH is the one missing the plugin, and injecting into pipx's
      # copy changes nothing. PATH can list a folder twice, so de-duplicate.
      poetry_paths=$(type -ap poetry 2>/dev/null | awk '!seen[$0]++')
      poetry_count=$(printf '%s\n' "$poetry_paths" | grep -c .)
      if [ "$poetry_count" -ge 2 ]; then
        poetry_first=$(printf '%s\n' "$poetry_paths" | head -n 1)
        poetry_others=$(printf '%s\n' "$poetry_paths" | awk 'NR > 1 { printf "%s%s", (NR > 2 ? ", " : ""), $0 }')
        export_problem="More than one Poetry is installed, and the first one on your PATH ($poetry_first) is missing the export plugin. Other copies: $poetry_others"
        case "$poetry_first" in
          /opt/homebrew/* | /usr/local/*)
            export_fix="Run 'brew uninstall poetry', then 'hash -r'. Keep the pipx copy."
            ;;
          *)
            export_fix="Remove the extra Poetry at $poetry_first so the pipx copy comes first on your PATH, then run 'hash -r'."
            ;;
        esac
      fi
    fi
    fail "$export_problem" "$export_fix" "$(page python-and-poetry)"
  fi

  in_project=$(cd / && poetry config virtualenvs.in-project 2>/dev/null | tail -n 1)
  if [ "$in_project" = "null" ]; then
    in_project=""
  fi
  if [ "$in_project" = "true" ]; then
    pass "virtualenvs.in-project = true"
  else
    fail "virtualenvs.in-project is '${in_project:-not set}' (should be true)" \
      "poetry config virtualenvs.in-project true" \
      "$(page python-and-poetry)"
  fi

  if [ "$PLATFORM" = "cloudshell" ]; then
    case "$(command -v poetry)" in
      "$HOME"/*) pass "poetry is installed under \$HOME, so it persists" ;;
      *)
        warn "poetry is installed outside \$HOME ($(command -v poetry)) and will disappear when the session ends" \
          "Install Poetry with the official installer (page 3 of Part 3)." \
          "$(page python-and-poetry)"
        ;;
    esac
  fi
else
  fail "poetry is not installed (or not on your PATH)" \
    "Close and reopen your terminal. If it's still missing, repeat page 3 of your part of the guide." \
    "$(page python-and-poetry)"
fi

# --- VS Code ----------------------------------------------------------------

section "VS Code"
if [ "$PLATFORM" = "cloudshell" ]; then
  skip "VS Code and extensions"
elif ! have code; then
  if [ "$PLATFORM" = "mac" ]; then
    code_fix="In VS Code: Cmd+Shift+P > 'Shell Command: Install code command in PATH', then reopen Terminal."
  else
    code_fix="Install VS Code on Windows with 'Add to PATH' checked, then close and reopen Ubuntu."
  fi
  fail "'code' is not on your PATH" "$code_fix" "$(page vs-code)"
elif [ "$PLATFORM" = "wsl" ] && [ ! -d "$HOME/.vscode-server" ]; then
  # Without this check, 'code --list-extensions' would download the VS Code
  # server into WSL, and this script promises not to install anything.
  fail "VS Code hasn't connected to WSL yet" \
    "From Ubuntu, run: cd ~/projects && code ." \
    "$(page vs-code)"
else
  pass "'code' is on your PATH"

  extensions=$(code --list-extensions 2>/dev/null || true)
  if [ -z "$extensions" ]; then
    fail "Couldn't list VS Code extensions" \
      "Open VS Code once, then run this script again. On Windows, run it from Ubuntu." \
      "$(page vs-code)"
  else
    if [ "$PLATFORM" = "wsl" ]; then
      # remote-wsl lives on the Windows side, so it doesn't appear in WSL's
      # list. Listing extensions from inside WSL only works through it.
      pass "VS Code connects to WSL (WSL extension)"
    fi
    for ext in ms-python.python tamasfe.even-better-toml; do
      if printf '%s\n' "$extensions" | grep -qix "$ext"; then
        pass "Extension $ext installed"
      else
        fail "Extension $ext is not installed" \
          "code --install-extension $ext" \
          "$(page vs-code)"
      fi
    done
  fi
fi

# --- Google Cloud CLI -------------------------------------------------------

section "Google Cloud CLI"
if have gcloud; then
  gcloud_version=$(CLOUDSDK_CORE_DISABLE_PROMPTS=1 gcloud --version 2>/dev/null | head -n 1 | sed 's/^Google Cloud SDK //')
  pass "gcloud installed (${gcloud_version:-version unknown})"

  account=$(CLOUDSDK_CORE_DISABLE_PROMPTS=1 gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | head -n 1)
  if [ -n "$account" ]; then
    GCLOUD_ACCOUNT="$account"
    pass "gcloud has an active account ($account)"
  else
    fail "gcloud has no active account" \
      "gcloud auth login" \
      "$(page gcloud)"
  fi
else
  if [ "$PLATFORM" = "cloudshell" ]; then
    gcloud_fix="gcloud should be preinstalled in Cloud Shell. Reconnect and try again."
  else
    gcloud_fix="Install the Google Cloud CLI (page 5 of your part of the guide), then reopen your terminal."
  fi
  fail "gcloud is not installed" "$gcloud_fix" "$(page gcloud)"
fi

# --- Summary ----------------------------------------------------------------

line="════════════════════════════════════════════════════════════"
printf '\n%s\n' "$line"
printf '  MIS 58710 SETUP CHECK: SUMMARY (screenshot this box)\n'
printf '%s\n' "$line"
printf '  Platform:    %s\n' "$PLATFORM_NAME"
printf '  Date/time:   %s\n' "$(date '+%Y-%m-%d %H:%M %Z')"
printf '  GitHub user: %s\n' "$GH_USER"
printf '  gcloud:      %s\n' "$GCLOUD_ACCOUNT"
printf '  Checks:      %d passed, %d failed, %d warning(s)\n' "$PASS" "$FAIL" "$WARN"
if [ "$FAIL" -eq 0 ]; then
  printf '  Result:      ✅ PASS\n'
else
  printf '  Result:      ❌ FAIL (fix the ❌ items above and run again)\n'
fi
printf '%s\n\n' "$line"

if [ "$FAIL" -eq 0 ]; then
  exit 0
fi
exit 1
