# setup-scripts

Interactive setup for a new Apple Silicon Mac. The script uses [`gum`](https://github.com/charmbracelet/gum) for checkbox menus.

## Usage

```sh
curl -fsSL https://raw.githubusercontent.com/DanGrund/setup-scripts/main/shareable-mac-setup.sh -o shareable-mac-setup.sh && bash shareable-mac-setup.sh
```

Do not pipe it into `bash`. The prompts need a real TTY.

## What it does

- Installs Xcode Command Line Tools, Homebrew, `gum`, git, and an SSH key.
- Sets a few macOS defaults for screenshots, Dock autohide, and keyboard repeat.
- Prompts for git identity, terminal tools, CLI tools, runtimes, dev apps, AI tools, productivity apps, and CTF/security tools.
- Merges selected oh-my-zsh plugins into `~/.zshrc`.
- Adds starship and zoxide init lines when selected.
- Sets delta as the git pager when selected.
- Offers Claude Code plugins when Claude Code is selected.

Use **x** or **Space** to toggle items and **Enter** to confirm a menu. Use **Esc** or **Ctrl+C** to abort.

## Dry run

```sh
brew install gum
bash shareable-mac-setup.sh --dry-run
```

Dry run shows each action as `[dry-run] ...` and skips system changes.

## Manual follow-ups

- Set the zsh theme in `~/.zshrc` if you want `agnoster`.
- Set iTerm2's font to "FiraCode Nerd Font" if you use that theme.
- Set VS Code's font to "FiraCode Nerd Font" and enable ligatures if desired.
- Run `rustup-init` if you selected `rust`.
- Download Superconductor and Conductor manually: <https://super.engineering/> and <https://conductor.build/>.
