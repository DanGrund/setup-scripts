# setup-scripts

- Open Terminal and run
`curl -fsSL https://raw.githubusercontent.com/DanGrund/setup-scripts/main/mac-setup.sh -o mac-setup.sh && bash mac-setup.sh`

  The script is interactive — after Homebrew installs, it bootstraps [`gum`](https://github.com/charmbracelet/gum) and shows checkbox menus at each step (Languages, Development Apps, AI Coding Tools, Productivity Apps, Useful Binaries, CTF Tools, Claude Code Plugins). Use Space to toggle, Enter to confirm. Sensible defaults are pre-checked, so hitting Enter through each menu gives you a normal install.

  `curl ... | bash` will not work — the interactive prompts need a real TTY, which is why the install command downloads first.

  Always installed (no prompt): Xcode CLI tools, Homebrew, iTerm2, tmux, git + SSH key, oh-my-zsh + plugins, Fira Code Nerd Font.

- update zsh theme, open `~/.zshrc`
    - set theme to `agnoster`
    - add the following to plugins:
        - `zsh-syntax-highlighting`
        - `zsh-autosuggestions`

- in iterm2 preferences, go to profiles->text and update the font to "FiraCode Nerd Font" for the agnoster theme to work
- in vs code settings, update the typeface to FiraCode Nerd Font, and enable ligatures
