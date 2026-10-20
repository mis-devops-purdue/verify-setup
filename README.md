# verify-setup

A script that checks your **MIS 58710** Week 1 setup and prints a summary to screenshot for **Prep 3 – Set Up Your Computer for DevOps**.

Setup instructions are in the [MIS 58710 Setup Guide](https://mis-devops-purdue.github.io/setup-guide/). This repository is used on the guide's [Verify your setup](https://mis-devops-purdue.github.io/setup-guide/verify/) page.

## Run it

In your terminal (Ubuntu on Windows, Terminal on a Mac, or Cloud Shell):

```bash
cd ~
gh repo clone mis-devops-purdue/verify-setup
bash verify-setup/verify.sh
```

Cloning with `gh` is itself the first check: if it works, your GitHub sign-in works.

To get the latest version later:

```bash
git -C ~/verify-setup pull
```

## What it checks

| Check | Windows (WSL) | Mac | Cloud Shell |
| --- | :-: | :-: | :-: |
| Which platform you're on (stops with ❌ on Windows outside WSL) | ✓ | ✓ | ✓ |
| Current folder isn't under `/mnt/c` (warning only) | ✓ | | |
| `git` installed; `user.name` and `user.email` set | ✓ | ✓ | ✓ |
| `gh` installed; `gh auth status` succeeds | ✓ | ✓ | ✓ |
| `python3` is 3.11 or newer | ✓ | ✓ | ✓ |
| `pipx` on your PATH | ✓ | ✓ | |
| `poetry` is 2.0 or newer | ✓ | ✓ | ✓ |
| Poetry export plugin installed (`poetry export --help` works) | ✓ | ✓ | ✓ |
| `poetry config virtualenvs.in-project` is `true` | ✓ | ✓ | ✓ |
| Poetry installed under `$HOME`, so it persists (warning only) | | | ✓ |
| `code` on your PATH; VS Code connects to WSL | ✓ | ✓ | |
| VS Code extensions `ms-python.python` and `tamasfe.even-better-toml` | ✓ | ✓ | |
| `gcloud` installed; an active account in `gcloud auth list` | ✓ | ✓ | ✓ |

Every ❌ comes with a one-line fix and a link to the guide page to revisit. The script exits with status 0 when nothing failed and 1 otherwise.

The summary box at the end shows your platform, the date and time, your GitHub username, your active Google Cloud account, and the pass/fail count.

## It changes nothing

This script is **read-only**. It never installs, updates, or deletes anything; it never changes a setting; and it never uses `sudo` or asks for a password. It only runs commands that report versions and status, such as `git config --global user.name`, `gh auth status`, `poetry --version`, `code --list-extensions`, and `gcloud auth list`.

Don't take that on trust: [`verify.sh`](verify.sh) is under 400 lines of plain bash, and reading it before you run it takes a few minutes. Running a script from the internet gives it the same access you have, so checking what it does first is a good habit, in this course and after it.

## For maintainers

- `verify.sh` must run under **bash 3.2** (the version macOS ships): no associative arrays, no `mapfile`, no `${var,,}`.
- It must pass [ShellCheck](https://www.shellcheck.net/) with no warnings: `shellcheck verify.sh`.
- The guide URLs it prints come from the setup guide's page slugs (for example `.../setup-guide/mac/python-and-poetry/`). If a page is renamed there, update `verify.sh` too.
