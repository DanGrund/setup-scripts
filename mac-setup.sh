#!/usr/bin/env bash

# Copied bits and pieces from donnemartin/dev-setup, the stuff I need to get up and running on a new mac
# To Execute, run:
# curl -fsSL https://raw.githubusercontent.com/DanGrund/setup-scripts/main/mac-setup.sh | bash

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

# Install iTerm2
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

# Install Python
echo "Installing python..."
brew install python

# Install ruby
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

# Install vim
#echo "Installing vim..."
#brew install vim

# Install Powerline-compatible fonts via Homebrew (includes Fira Code + Powerline glyphs)
echo "Installing Nerd Fonts (Fira Code)..."
brew install --cask font-fira-code-nerd-font

# Development Apps
brew install node
brew install lazygit
brew install gh
brew install jq
brew install delta
#brew install --cask visual-studio-code
brew install --cask webstorm
#brew install --cask dbeaver-community
brew install --cask docker
brew install --cask postman
#brew install --cask pgadmin4
#brew install libpq

# AI Coding Tools
echo "Installing Claude Code..."
npm install -g @anthropic-ai/claude-code

echo "Installing Codex CLI..."
npm install -g @openai/codex

# Superconductor — parallel AI agent runner (no homebrew cask, download manually)
echo "NOTE: Download Superconductor manually from https://super.engineering/"

# Upload SSH key to GitHub (requires gh auth first)
if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    echo "Authenticating with GitHub..."
    gh auth login
    gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --title "$(hostname)"
fi

# Productivity Apps
brew install --cask firefox
#brew install --cask google-chrome
brew install --cask slack
#brew install --cask discord
brew install --cask notion
brew install --cask rectangle
brew install --cask spotify

# Useful Binaries
brew install speedtest-cli      # ookla in your CLI, so you can always complain about comcast
#brew install nmap               # diagnose network connections
brew install wget               # downloads
brew install imagemagick         # image processing (includes webp support)

# CTF tools, for when you want to get your Mr. Robot on
# brew install aircrack-ng
# brew install bfg
# brew install binutils
# brew install binwalk
# brew install cifer
# brew install dex2jar
# brew install dns2tcp
# brew install fcrackzip
# brew install foremost
# brew install hashpump
# brew install hydra
# brew install john
# brew install knock
# brew install netpbm
# brew install nmap
# brew install pngcheck
# brew install socat
# brew install sqlmap
# brew install tcpflow
# brew install tcpreplay
# brew install tcptrace
# brew install ucspi-tcp # `tcpserver` etc.
# brew install xz

# Claude Code Configuration
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

# Install plugins
echo "Installing Claude Code plugins..."
claude plugins install superpowers@claude-plugins-official 2>/dev/null
claude plugins install frontend-design@claude-plugins-official 2>/dev/null
claude plugins install feature-dev@claude-plugins-official 2>/dev/null
claude plugins install code-simplifier@claude-plugins-official 2>/dev/null
claude plugins install playground@claude-plugins-official 2>/dev/null
claude plugins install ralph-loop@claude-plugins-official 2>/dev/null
claude plugins install compound-engineering@compound-engineering-plugin 2>/dev/null
echo "Claude Code plugins installed."

# Remove outdated versions from the cellar.
echo "Running brew cleanup..."
brew cleanup
echo "You're done!"
