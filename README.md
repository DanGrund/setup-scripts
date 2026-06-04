# setup-scripts

Interactive macOS setup script built around [`gum`](https://github.com/charmbracelet/gum) checkbox menus.

## Usage

Open Terminal and run:

```sh
curl -fsSL https://raw.githubusercontent.com/DanGrund/setup-scripts/main/shareable-mac-setup.sh -o shareable-mac-setup.sh && bash shareable-mac-setup.sh
```

`curl ... | bash` will not work — the interactive prompts need a real TTY, which is why the install command downloads first.

## How it works

- After Homebrew installs, the script bootstraps `gum` and walks you through each step: git identity → Terminal & Shell → oh-my-zsh plugins → CLI Tools → Languages & Runtimes → Development Apps → AI Coding Tools → Claude Code plugins → Productivity Apps → CTF tools → GitHub SSH key upload.
- **Space** toggles an item, **Enter** confirms the menu. Sensible defaults are pre-checked, so hitting Enter through each menu gives a normal install.
- **Esc or Ctrl+C** in any prompt aborts the whole script. Enter with nothing selected just skips that section.
- Always installed (no prompt): Xcode CLI tools, Homebrew, macOS preference tweaks, git + SSH key.
- Selecting Claude Code also offers a selectable plugin list.
- Post-install wiring happens automatically: oh-my-zsh plugin selections are merged into the `plugins=(...)` line in `~/.zshrc` (manual additions are preserved), starship/zoxide get their init lines, delta becomes git's pager, and the modern CLI tools (bat/eza/ripgrep/fd/btop) get guarded aliases.

## Dry run

Preview every menu and see exactly what would be installed, without touching the system:

```sh
brew install gum   # required for the menus
bash shareable-mac-setup.sh --dry-run
```

Actions print inline as `[dry-run] ...` and a full summary is listed at the end.

## Manual follow-ups

- update zsh theme, open `~/.zshrc`
    - set theme to `agnoster`
- in iterm2 preferences, go to profiles->text and update the font to "FiraCode Nerd Font" for the agnoster theme to work
- in vs code settings, update the typeface to FiraCode Nerd Font, and enable ligatures
- if you selected `rust`, run `rustup-init` to install the toolchain
- Superconductor and Conductor are manual downloads: <https://super.engineering/> and <https://conductor.build/>
