#!/usr/bin/env bash

# Copied bits and pieces from donnemartin/dev-setup, the stuff I need to get up and running on a new mac
# To Execute, run:
#   curl -fsSL https://raw.githubusercontent.com/DanGrund/setup-scripts/main/mac-setup.sh -o mac-setup.sh && bash mac-setup.sh
# (download-then-run is required because the interactive prompts need a real TTY)

# Ask for the administrator password, required to run a few of the installs
sudo -v

# Keep-alive: update existing `sudo` time stamp until the script has finished.
while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" || exit
done 2>/dev/null &

echo "------------------------------"
echo "Installing Xcode Command Line Tools."
if ! xcode-select -p &>/dev/null; then
    xcode-select --install
    echo "Waiting for Xcode Command Line Tools installation..."
    until xcode-select -p &>/dev/null; do
        sleep 5
    done
else
    echo "Xcode Command Line Tools already installed."
fi

# macOS configs
echo "------------------------------"
echo "Updating system preferences"

defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true
defaults write com.apple.dock autohide -bool true
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
killall SystemUIServer 2>/dev/null
killall Dock 2>/dev/null

echo "------------------------------"

# Check for Homebrew, and then install it
if ! command -v brew &>/dev/null; then
    echo "Installing homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo "Homebrew installed successfully"
else
    echo "Homebrew already installed!"
fi

if ! grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
    (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> "$HOME/.zprofile"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"
brew config

# Updating Homebrew.
echo "Updating Homebrew..."
brew update

# Upgrade any already-installed formulae.
echo "Upgrading Homebrew..."
brew upgrade

# Install gum (Charmbracelet) so we can show interactive prompts for the rest.
if ! command -v gum &>/dev/null; then
    echo "Installing gum..."
    brew install gum
fi

# select_and_install <header> <pkg|y|n>...
# Items prefixed with "cask:" install via --cask. The y/n flag sets whether
# the item is pre-checked. Output of gum (one selected item per line) is
# piped through brew install.
select_and_install() {
    local header="$1"; shift
    local options=() defaults=()
    local item pkg def
    for item in "$@"; do
        pkg="${item%|*}"
        def="${item##*|}"
        options+=("$pkg")
        [ "$def" = "y" ] && defaults+=("$pkg")
    done

    local selected_flag=()
    if [ ${#defaults[@]} -gt 0 ]; then
        local joined
        joined=$(IFS=','; echo "${defaults[*]}")
        selected_flag=(--selected="$joined")
    fi

    local chosen
    chosen=$(gum choose --no-limit --height 20 --header "$header" \
        "${selected_flag[@]}" "${options[@]}" < /dev/tty)

    while IFS= read -r pkg; do
        [ -z "$pkg" ] && continue
        if [[ "$pkg" == cask:* ]]; then
            brew install --cask "${pkg#cask:}"
        else
            brew install "$pkg"
        fi
    done <<< "$chosen"
}

# select_list <header> <item|y|n>...
# Generic multi-select that just echoes the chosen items (one per line).
select_list() {
    local header="$1"; shift
    local options=() defaults=()
    local item label def
    for item in "$@"; do
        label="${item%|*}"
        def="${item##*|}"
        options+=("$label")
        [ "$def" = "y" ] && defaults+=("$label")
    done

    local selected_flag=()
    if [ ${#defaults[@]} -gt 0 ]; then
        local joined
        joined=$(IFS=','; echo "${defaults[*]}")
        selected_flag=(--selected="$joined")
    fi

    gum choose --no-limit --height 20 --header "$header" \
        "${selected_flag[@]}" "${options[@]}" < /dev/tty
}

# Terminal essentials (always installed)
echo "Installing iTerm2..."
brew install --cask iterm2

echo "Installing TMUX..."
brew install tmux

# Install Git (before oh-my-zsh plugins that need it)
if ! command -v git &>/dev/null; then
    echo "Installing Git..."
    brew install git
else
    echo "git already installed!"
fi

git config --global user.name "Dan Grund"
git config --global user.email "hello@dangrund.com"
git config --global pager.branch false
git config --global init.defaultBranch main
git config --global core.pager delta

# Generate SSH key for GitHub if one doesn't exist
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "Generating SSH key..."
    ssh-keygen -t ed25519 -C "hello@dangrund.com" -f "$HOME/.ssh/id_ed25519" -N ""
    eval "$(ssh-agent -s)"
    ssh-add "$HOME/.ssh/id_ed25519"
fi

# Install oh-my-zsh
echo "Installing oh-my-zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "oh-my-zsh already installed!"
fi

if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
fi
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
fi

# Languages
LANGS=$(select_list "Languages" \
    "python|y" \
    "ruby|y")

if echo "$LANGS" | grep -qx python; then
    echo "Installing python..."
    brew install python
fi

if echo "$LANGS" | grep -qx ruby; then
    if ! command -v ruby &>/dev/null || [ "$(which ruby)" = "/usr/bin/ruby" ]; then
        echo "Installing Ruby..."
        brew install ruby
        echo "Adding the brew ruby path to shell config..."
        if ! grep -q 'ruby/bin' "$HOME/.zprofile" 2>/dev/null; then
            echo 'export PATH="/opt/homebrew/opt/ruby/bin:$PATH"' >> "$HOME/.zprofile"
        fi
    else
        echo "Ruby already installed!"
    fi
fi

# Install Powerline-compatible fonts via Homebrew (includes Fira Code + Powerline glyphs)
echo "Installing Nerd Fonts (Fira Code)..."
brew install --cask font-fira-code-nerd-font

# Development Apps
select_and_install "Development Apps" \
    "node|y" \
    "lazygit|y" \
    "gh|y" \
    "jq|y" \
    "delta|y" \
    "cask:visual-studio-code|n" \
    "cask:webstorm|y" \
    "cask:dbeaver-community|n" \
    "cask:docker|y" \
    "cask:postman|y" \
    "cask:pgadmin4|n" \
    "libpq|n"

# AI Coding Tools
AI_TOOLS=$(select_list "AI Coding Tools" \
    "Claude Code|y" \
    "Codex CLI|y" \
    "Superconductor (manual download)|y")

if echo "$AI_TOOLS" | grep -qx "Claude Code"; then
    if command -v npm &>/dev/null; then
        echo "Installing Claude Code..."
        npm install -g @anthropic-ai/claude-code
    else
        echo "Skipping Claude Code: npm not installed (select 'node' in Development Apps)."
    fi
fi

if echo "$AI_TOOLS" | grep -qx "Codex CLI"; then
    if command -v npm &>/dev/null; then
        echo "Installing Codex CLI..."
        npm install -g @openai/codex
    else
        echo "Skipping Codex CLI: npm not installed (select 'node' in Development Apps)."
    fi
fi

if echo "$AI_TOOLS" | grep -qx "Superconductor (manual download)"; then
    echo "NOTE: Download Superconductor manually from https://super.engineering/"
fi

# Upload SSH key to GitHub (requires gh auth first)
if [ -f "$HOME/.ssh/id_ed25519.pub" ] && command -v gh &>/dev/null; then
    if gum confirm "Authenticate with GitHub and upload your SSH key now?" < /dev/tty; then
        gh auth login
        gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --title "$(hostname)"
    fi
fi

# Productivity Apps
select_and_install "Productivity Apps" \
    "cask:firefox|y" \
    "cask:google-chrome|n" \
    "cask:slack|y" \
    "cask:discord|n" \
    "cask:notion|y" \
    "cask:rectangle|y" \
    "cask:spotify|y"

# Useful Binaries
select_and_install "Useful Binaries" \
    "speedtest-cli|y" \
    "wget|y" \
    "imagemagick|y" \
    "nmap|n"

# CTF tools, for when you want to get your Mr. Robot on
if gum confirm "Install CTF / security tools?" --default=No < /dev/tty; then
    select_and_install "CTF Tools" \
        "aircrack-ng|n" \
        "bfg|n" \
        "binutils|n" \
        "binwalk|n" \
        "cifer|n" \
        "dex2jar|n" \
        "dns2tcp|n" \
        "fcrackzip|n" \
        "foremost|n" \
        "hashpump|n" \
        "hydra|n" \
        "john|n" \
        "knock|n" \
        "netpbm|n" \
        "pngcheck|n" \
        "socat|n" \
        "sqlmap|n" \
        "tcpflow|n" \
        "tcpreplay|n" \
        "tcptrace|n" \
        "ucspi-tcp|n" \
        "xz|n"
fi

# Claude Code Configuration
if command -v claude &>/dev/null; then
    echo "------------------------------"
    echo "Setting up Claude Code..."

    CLAUDE_DIR="$HOME/.claude"
    SETUP_REPO="$HOME/setup-scripts"

    # Clone the setup repo to get config files
    if [ ! -d "$SETUP_REPO" ]; then
        git clone https://github.com/DanGrund/setup-scripts.git "$SETUP_REPO"
    fi

    # Copy base settings (won't overwrite if already customized)
    if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
        cp "$SETUP_REPO/claude/settings.json" "$CLAUDE_DIR/settings.json"
        echo "Claude Code settings installed."
    else
        echo "Claude Code settings already exist, skipping."
    fi

    # Copy custom agents
    mkdir -p "$CLAUDE_DIR/agents"
    cp -n "$SETUP_REPO/claude/agents/"*.md "$CLAUDE_DIR/agents/" 2>/dev/null
    echo "Custom agents installed."

    # Install plugins (user-selectable)
    PLUGINS=$(select_list "Claude Code Plugins" \
        "superpowers@claude-plugins-official|y" \
        "frontend-design@claude-plugins-official|y" \
        "feature-dev@claude-plugins-official|y" \
        "code-simplifier@claude-plugins-official|y" \
        "playground@claude-plugins-official|y" \
        "ralph-loop@claude-plugins-official|y" \
        "compound-engineering@compound-engineering-plugin|y")

    while IFS= read -r plugin; do
        [ -z "$plugin" ] && continue
        echo "Installing $plugin..."
        claude plugins install "$plugin" 2>/dev/null
    done <<< "$PLUGINS"
    echo "Claude Code plugins installed."
fi

# Remove outdated versions from the cellar.
echo "Running brew cleanup..."
brew cleanup
echo "You're done!"
