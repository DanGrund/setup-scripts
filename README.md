# setup-scripts

- Open Terminal and run
`curl -fsSL https://raw.githubusercontent.com/DanGrund/setup-scripts/main/mac-setup.sh | sh`

- update zsh theme, open `~/.zshrc`
    - set theme to `agnoster`
    - add the following to plugins:
        - `zsh-syntax-highlighting`
        - `zsh-autosuggestions`
- git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
- git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
