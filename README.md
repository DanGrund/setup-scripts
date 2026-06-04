# setup-scripts

interactive setup for a new macs (silicon only, not tested on intel sorry). 

updated from my own config migration to a configurable, shareable setup script using [`gum`](https://github.com/charmbracelet/gum) for checkbox menus

## Usage

```sh
curl -fsSL https://raw.githubusercontent.com/DanGrund/setup-scripts/main/shareable-mac-setup.sh -o shareable-mac-setup.sh && bash shareable-mac-setup.sh
```
don't pipe it into `bash`. the prompts need a real TTY.

you can also fire a dry run if you install brew and gum first

```sh
brew install gum
bash shareable-mac-setup.sh --dry-run
```

## What it do

- Installs Xcode Command Line Tools, Homebrew, `gum`, git, and sets up your github SSH key.
- Sets a few macOS defaults for screenshots, Dock autohide, and keyboard repeat.
- Prompts for git identity, terminal tools, CLI tools, runtimes, dev apps, AI tools, productivity apps, "media archiving and discovery" apps, and a collection of defcon toys.
- Can scaffold a Docker Compose media stack template without starting containers.
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
