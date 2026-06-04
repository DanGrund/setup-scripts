#!/usr/bin/env bash

# Shareable interactive mac setup — prompts for your identity and lets you pick what to install.
# To Execute, run:
#   curl -fsSL https://raw.githubusercontent.com/DanGrund/setup-scripts/main/shareable-mac-setup.sh -o shareable-mac-setup.sh && bash shareable-mac-setup.sh
# (download-then-run is required because the interactive prompts need a real TTY)
#
# Options:
#   --dry-run   Walk through every prompt without installing or configuring
#               anything; prints a summary of what would have run.
#               Requires gum to be installed already: brew install gum

DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        *) echo "Unknown option: $arg" >&2; echo "Usage: $0 [--dry-run]" >&2; exit 2 ;;
    esac
done

DRY_LOG=()

# run <cmd...> — execute a command, or log it instead in dry-run mode.
run() {
    if $DRY_RUN; then
        echo "[dry-run] $*"
        DRY_LOG+=("$*")
    else
        "$@"
    fi
}

# plan <description> — log a non-command action (file append, merge, etc.)
# in dry-run mode. Only called from inside dry-run branches.
plan() {
    echo "[dry-run] $*"
    DRY_LOG+=("$*")
}

if $DRY_RUN; then
    echo "=== DRY RUN — nothing will be installed or configured ==="
    if ! command -v gum &>/dev/null; then
        echo "gum is required for the menus. Install it first: brew install gum" >&2
        exit 1
    fi
    plan "install Xcode Command Line Tools (if missing)"
    plan "write macOS defaults (screenshot format, dock autohide, key repeat)"
    plan "install/update Homebrew"
else
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
fi

# Esc or Ctrl+C in any prompt aborts the whole script.
# (Enter with nothing selected just skips that section.)
abort() {
    echo
    echo "Setup aborted — no further changes made."
    exit 130
}

# confirm <question> [gum confirm flags...]
# Like gum confirm, but Esc/Ctrl+C aborts the script instead of meaning "no".
confirm() {
    gum confirm "$@" < /dev/tty
    local rc=$?
    [ "$rc" -eq 130 ] && abort
    return $rc
}

# Every package picked in any menu, with cask: prefixes stripped. Lets
# post-install wiring ask "was this chosen?" even in dry-run mode where
# nothing actually gets installed.
SELECTED=()

# was_picked <name> — true if <name> is installed or was selected in a menu.
was_picked() {
    command -v "$1" &>/dev/null && return 0
    local p
    for p in "${SELECTED[@]}"; do
        [ "$p" = "$1" ] && return 0
    done
    return 1
}

# select_and_install <header> <pkg|y|n>...
# Items prefixed with "cask:" install via --cask; the prefix is stripped
# from the menu display. The y/n flag sets whether the item is pre-checked.
select_and_install() {
    local header="$1"; shift
    local options=() defaults=() casks=()
    local item pkg def name
    for item in "$@"; do
        pkg="${item%|*}"
        def="${item##*|}"
        name="${pkg#cask:}"
        options+=("$name")
        [[ "$pkg" == cask:* ]] && casks+=("$name")
        [ "$def" = "y" ] && defaults+=("$name")
    done

    local selected_flag=()
    if [ ${#defaults[@]} -gt 0 ]; then
        local joined
        joined=$(IFS=','; echo "${defaults[*]}")
        selected_flag=(--selected="$joined")
    fi

    local chosen
    chosen=$(gum choose --no-limit --height 20 --header "$header" \
        "${selected_flag[@]}" "${options[@]}" < /dev/tty) || abort

    while IFS= read -r name; do
        [ -z "$name" ] && continue
        SELECTED+=("$name")
        case " ${casks[*]} " in
            *" $name "*) run brew install --cask "$name" ;;
            *)           run brew install "$name" ;;
        esac
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

# Install Git (before oh-my-zsh plugins that need it)
if ! command -v git &>/dev/null; then
    echo "Installing Git..."
    run brew install git
else
    echo "git already installed!"
fi

# Git identity — prompt for name and email (pre-filled with any existing config)
GIT_NAME=$(gum input --header "Git user.name" \
    --value "$(git config --global user.name 2>/dev/null)" \
    --placeholder "Jane Doe" < /dev/tty) || abort
GIT_EMAIL=$(gum input --header "Git user.email" \
    --value "$(git config --global user.email 2>/dev/null)" \
    --placeholder "jane@example.com" < /dev/tty) || abort

[ -n "$GIT_NAME" ] && run git config --global user.name "$GIT_NAME"
[ -n "$GIT_EMAIL" ] && run git config --global user.email "$GIT_EMAIL"
run git config --global pager.branch false
run git config --global init.defaultBranch main

# Generate SSH key for GitHub if one doesn't exist
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    if $DRY_RUN; then
        plan "generate ed25519 SSH key (${GIT_EMAIL:-no email})"
    else
        echo "Generating SSH key..."
        ssh-keygen -t ed25519 -C "${GIT_EMAIL:-$(git config --global user.email 2>/dev/null)}" -f "$HOME/.ssh/id_ed25519" -N ""
        eval "$(ssh-agent -s)"
        ssh-add "$HOME/.ssh/id_ed25519"
    fi
fi

# Terminal & Shell — emulators, multiplexers, editors, prompt, font.
# (font-fira-code-nerd-font is a Powerline-compatible Nerd Font.)
select_and_install "Terminal & Shell" \
    "cask:iterm2|y" \
    "cask:ghostty|n" \
    "cask:warp|n" \
    "cask:alacritty|n" \
    "tmux|y" \
    "zellij|n" \
    "vim|n" \
    "neovim|n" \
    "emacs|n" \
    "starship|n" \
    "zoxide|n" \
    "cask:font-fira-code-nerd-font|y"

# oh-my-zsh — optional, with a pick-list of the most useful plugins.
# zsh-syntax-highlighting is listed last on purpose: it must load last.
if confirm "Improve your terminal with oh-my-zsh?"; then
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        if $DRY_RUN; then
            plan "install oh-my-zsh"
        else
            echo "Installing oh-my-zsh..."
            RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        fi
    else
        echo "oh-my-zsh already installed!"
    fi

    ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    OMZ_PLUGINS=$(select_list "oh-my-zsh plugins" \
        "git|y" \
        "macos|y" \
        "gh|y" \
        "npm|y" \
        "node|y" \
        "z|y" \
        "extract|y" \
        "colored-man-pages|y" \
        "fzf|y" \
        "sudo|n" \
        "web-search|n" \
        "dirhistory|n" \
        "docker|n" \
        "zsh-completions|n" \
        "zsh-autosuggestions|y" \
        "zsh-syntax-highlighting|y") || abort

    # Third-party plugins need a git clone into the custom plugins dir;
    # the rest ship with oh-my-zsh and only need enabling in .zshrc.
    for ext in zsh-completions zsh-autosuggestions zsh-syntax-highlighting; do
        if echo "$OMZ_PLUGINS" | grep -qx "$ext" && [ ! -d "$ZSH_CUSTOM_DIR/plugins/$ext" ]; then
            run git clone "https://github.com/zsh-users/$ext.git" "$ZSH_CUSTOM_DIR/plugins/$ext"
        fi
    done

    # Enable the selected plugins in ~/.zshrc, merging with whatever is
    # already there so manual additions are never clobbered.
    PLUGIN_LIST=$(echo "$OMZ_PLUGINS" | tr '\n' ' ' | sed 's/ *$//')
    if [ -n "$PLUGIN_LIST" ]; then
        EXISTING=$(sed -n 's/^plugins=(\(.*\))/\1/p' "$HOME/.zshrc" 2>/dev/null)
        MERGED=""
        for p in $EXISTING $PLUGIN_LIST; do
            case " $MERGED " in
                *" $p "*) ;;                 # already in the list, skip
                *) MERGED="$MERGED $p" ;;
            esac
        done
        MERGED="${MERGED# }"
        # zsh-syntax-highlighting must load last — move it to the end if present
        if [[ " $MERGED " == *" zsh-syntax-highlighting "* ]]; then
            MERGED=$(echo "$MERGED" | sed 's/zsh-syntax-highlighting//; s/  */ /g; s/^ *//; s/ *$//')
            MERGED="$MERGED zsh-syntax-highlighting"
        fi
        if $DRY_RUN; then
            plan "set ~/.zshrc to plugins=($MERGED)"
        elif [ -f "$HOME/.zshrc" ]; then
            sed -i '' "s/^plugins=(.*)/plugins=($MERGED)/" "$HOME/.zshrc"
            echo "Enabled oh-my-zsh plugins: $MERGED"
        fi
    fi
fi

# Wire up shell extras in ~/.zshrc if they're installed (or just picked).
# Done after the oh-my-zsh step because installing omz replaces ~/.zshrc.
if was_picked starship && ! grep -q 'starship init' "$HOME/.zshrc" 2>/dev/null; then
    if $DRY_RUN; then
        plan "append starship init to ~/.zshrc"
    else
        echo 'eval "$(starship init zsh)"' >> "$HOME/.zshrc"
        echo "Added starship init to ~/.zshrc"
    fi
fi
if was_picked zoxide && ! grep -q 'zoxide init' "$HOME/.zshrc" 2>/dev/null; then
    if $DRY_RUN; then
        plan "append zoxide init to ~/.zshrc"
    else
        echo 'eval "$(zoxide init zsh)"' >> "$HOME/.zshrc"
        echo "Added zoxide init to ~/.zshrc"
    fi
fi

# CLI Tools — command-line utilities (includes the old "Useful Binaries")
# bat/eza/ripgrep/fd/btop are modern replacements for cat/ls/grep/find/top.
select_and_install "CLI Tools" \
    "lazygit|y" \
    "gh|y" \
    "jq|y" \
    "delta|y" \
    "fzf|y" \
    "bat|y" \
    "eza|y" \
    "ripgrep|y" \
    "fd|y" \
    "btop|y" \
    "wget|y" \
    "speedtest-cli|y" \
    "imagemagick|y" \
    "nmap|n" \
    "libpq|n"

# Use delta as git's pager only if it's actually installed (or just picked)
if was_picked delta; then
    run git config --global core.pager delta
fi

# Aliases for the modern CLI replacements. The block self-guards with
# `command -v`, so each alias only activates if the tool is installed —
# safe to add once and forget. rg/fd flags differ from grep/find; remove
# those lines from ~/.zshrc if the muscle memory mismatch bites.
if was_picked bat || was_picked eza || was_picked ripgrep || was_picked fd || was_picked btop; then
    if ! grep -q '# modern-cli-aliases' "$HOME/.zshrc" 2>/dev/null; then
        if $DRY_RUN; then
            plan "append modern-cli-aliases block (cat→bat, ls→eza, grep→rg, find→fd, top→btop) to ~/.zshrc"
        else
            cat >> "$HOME/.zshrc" <<'EOF'

# modern-cli-aliases — added by setup script
command -v bat &>/dev/null && alias cat='bat --paging=never'
command -v eza &>/dev/null && alias ls='eza'
command -v rg &>/dev/null && alias grep='rg'
command -v fd &>/dev/null && alias find='fd'
command -v btop &>/dev/null && alias top='btop'
EOF
            echo "Added modern CLI aliases to ~/.zshrc"
        fi
    fi
fi

# Languages & Runtimes
LANGS=$(select_list "Languages & Runtimes" \
    "node|y" \
    "bun|y" \
    "pnpm|y" \
    "yarn|n" \
    "deno|n" \
    "python|y" \
    "uv|n" \
    "ruby|y" \
    "go|n" \
    "rust|n" \
    "java|n") || abort

if echo "$LANGS" | grep -qx node; then
    echo "Installing node..."
    run brew install node
fi

if echo "$LANGS" | grep -qx bun; then
    echo "Installing bun..."
    run brew install oven-sh/bun/bun
fi

if echo "$LANGS" | grep -qx pnpm; then
    echo "Installing pnpm..."
    run brew install pnpm
fi

if echo "$LANGS" | grep -qx yarn; then
    echo "Installing yarn..."
    run brew install yarn
fi

if echo "$LANGS" | grep -qx deno; then
    echo "Installing deno..."
    run brew install deno
fi

if echo "$LANGS" | grep -qx python; then
    echo "Installing python..."
    run brew install python
fi

if echo "$LANGS" | grep -qx uv; then
    echo "Installing uv..."
    run brew install uv
fi

if echo "$LANGS" | grep -qx go; then
    echo "Installing go..."
    run brew install go
fi

if echo "$LANGS" | grep -qx rust; then
    # rustup is the official Rust toolchain manager; the toolchain itself
    # is installed by running rustup-init afterwards.
    echo "Installing rustup..."
    run brew install rustup
    echo "NOTE: Run 'rustup-init' after setup to install the Rust toolchain."
fi

if echo "$LANGS" | grep -qx java; then
    # openjdk is keg-only, so it needs a PATH entry to be picked up.
    echo "Installing OpenJDK..."
    run brew install openjdk
    if ! grep -q 'openjdk/bin' "$HOME/.zprofile" 2>/dev/null; then
        if $DRY_RUN; then
            plan "add brew openjdk to PATH in ~/.zprofile"
        else
            echo "Adding the brew openjdk path to shell config..."
            echo 'export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"' >> "$HOME/.zprofile"
        fi
    fi
fi

if echo "$LANGS" | grep -qx ruby; then
    if ! command -v ruby &>/dev/null || [ "$(which ruby)" = "/usr/bin/ruby" ]; then
        echo "Installing Ruby..."
        run brew install ruby
        if ! grep -q 'ruby/bin' "$HOME/.zprofile" 2>/dev/null; then
            if $DRY_RUN; then
                plan "add brew ruby to PATH in ~/.zprofile"
            else
                echo "Adding the brew ruby path to shell config..."
                echo 'export PATH="/opt/homebrew/opt/ruby/bin:$PATH"' >> "$HOME/.zprofile"
            fi
        fi
    else
        echo "Ruby already installed!"
    fi
fi

# Development Apps (GUI)
# jetbrains-toolbox manages the whole JetBrains/IntelliJ family (WebStorm,
# IDEA, etc.) with shared installs and updates.
# orbstack is a faster, lighter Docker Desktop replacement (free for
# personal use) — pick it or docker, not both.
select_and_install "Development Apps" \
    "cask:visual-studio-code|y" \
    "cask:cursor|n" \
    "cask:zed|n" \
    "cask:windsurf|n" \
    "cask:sublime-text|n" \
    "cask:jetbrains-toolbox|n" \
    "cask:docker|y" \
    "cask:orbstack|n" \
    "cask:dbeaver-community|n" \
    "cask:tableplus|n" \
    "cask:pgadmin4|n" \
    "cask:postman|y" \
    "cask:bruno|n"

# AI Coding Tools
AI_TOOLS=$(select_list "AI Coding Tools" \
    "Claude Code|y" \
    "Codex CLI|y" \
    "Gemini CLI|n" \
    "OpenCode|n" \
    "GitHub Copilot CLI|n" \
    "Amp|n" \
    "Superconductor (manual download)|n" \
    "Conductor (manual download)|n") || abort

# install_ai_tool <menu label> <npm package> — installs if selected above
install_ai_tool() {
    local label="$1" pkg="$2"
    if echo "$AI_TOOLS" | grep -qx "$label"; then
        if command -v npm &>/dev/null || was_picked node; then
            echo "Installing $label..."
            run npm install -g "$pkg"
        else
            echo "Skipping $label: npm not installed (select 'node' in Languages & Runtimes)."
        fi
    fi
}

install_ai_tool "Claude Code" "@anthropic-ai/claude-code"
install_ai_tool "Codex CLI" "@openai/codex"
install_ai_tool "Gemini CLI" "@google/gemini-cli"
install_ai_tool "OpenCode" "opencode-ai"
install_ai_tool "GitHub Copilot CLI" "@github/copilot"
install_ai_tool "Amp" "@sourcegraph/amp"

if echo "$AI_TOOLS" | grep -qx "Superconductor (manual download)"; then
    echo "NOTE: Download Superconductor manually from https://super.engineering/"
fi

if echo "$AI_TOOLS" | grep -qx "Conductor (manual download)"; then
    echo "NOTE: Download Conductor manually from https://conductor.build/"
fi

# Claude Code Plugins — only when Claude Code was selected above
if echo "$AI_TOOLS" | grep -qx "Claude Code" && { command -v claude &>/dev/null || $DRY_RUN; }; then
    echo "------------------------------"
    echo "Setting up Claude Code plugins..."

    # Install plugins (user-selectable)
    PLUGINS=$(select_list "Claude Code Plugins" \
        "superpowers@claude-plugins-official|y" \
        "frontend-design@claude-plugins-official|y" \
        "feature-dev@claude-plugins-official|y" \
        "code-simplifier@claude-plugins-official|y" \
        "playground@claude-plugins-official|y" \
        "ralph-loop@claude-plugins-official|y" \
        "compound-engineering@compound-engineering-plugin|y" \
        "code-review@claude-plugins-official|n" \
        "pr-review-toolkit@claude-plugins-official|n" \
        "commit-commands@claude-plugins-official|n" \
        "security-guidance@claude-plugins-official|n" \
        "claude-md-management@claude-plugins-official|n" \
        "context7@claude-plugins-official|n" \
        "github@claude-plugins-official|n" \
        "hookify@claude-plugins-official|n") || abort

    while IFS= read -r plugin; do
        [ -z "$plugin" ] && continue
        if $DRY_RUN; then
            plan "claude plugins install $plugin"
        else
            echo "Installing $plugin..."
            claude plugins install "$plugin" 2>/dev/null
        fi
    done <<< "$PLUGINS"
fi

# Productivity Apps
select_and_install "Productivity Apps" \
    "cask:firefox|y" \
    "cask:google-chrome|n" \
    "cask:arc|n" \
    "cask:brave-browser|n" \
    "cask:slack|y" \
    "cask:discord|n" \
    "cask:zoom|n" \
    "cask:notion|y" \
    "cask:obsidian|n" \
    "cask:rectangle|y" \
    "cask:raycast|n" \
    "cask:1password|n" \
    "cask:figma|n" \
    "cask:the-unarchiver|n" \
    "cask:appcleaner|n" \
    "cask:stats|n" \
    "cask:vlc|n" \
    "cask:spotify|y"

# CTF tools, for when you want to get your Mr. Robot on
if confirm "Install CTF / security tools?" --default=No; then
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

# Upload SSH key to GitHub (requires gh auth first)
if { [ -f "$HOME/.ssh/id_ed25519.pub" ] || $DRY_RUN; } && was_picked gh; then
    if confirm "Authenticate with GitHub and upload your SSH key now?"; then
        if $DRY_RUN; then
            plan "gh auth login + gh ssh-key add ~/.ssh/id_ed25519.pub"
        else
            gh auth login
            gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --title "$(hostname)"
        fi
    fi
fi

if $DRY_RUN; then
    echo
    echo "=== Dry run complete — would have run: ==="
    if [ ${#DRY_LOG[@]} -eq 0 ]; then
        echo "(nothing selected)"
    else
        printf '  %s\n' "${DRY_LOG[@]}"
    fi
else
    # Remove outdated versions from the cellar.
    echo "Running brew cleanup..."
    brew cleanup
    echo "You're done!"
fi
