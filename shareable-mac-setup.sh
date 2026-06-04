#!/usr/bin/env bash

# Shareable interactive mac setup
# To Execute, run:
#   curl -fsSL https://raw.githubusercontent.com/DanGrund/setup-scripts/main/shareable-mac-setup.sh -o shareable-mac-setup.sh && bash shareable-mac-setup.sh
# (download-then-run is required because the interactive prompts need a real TTY)
#
# Options:
#   --dry-run   Walk through every prompt without installing or configuring anything;

DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        *) echo "Unknown option: $arg" >&2; echo "Usage: $0 [--dry-run]" >&2; exit 2 ;;
    esac
done

DRY_LOG=()
FAILED_LOG=()
XCODE_TIMEOUT_SECONDS=1800
XCODE_POLL_SECONDS=5

# run <cmd...> -- execute a command, or log it instead in dry-run mode.
run() {
    if $DRY_RUN; then
        echo "[dry-run] $*"
        DRY_LOG+=("$*")
    else
        "$@"
        local rc=$?
        if [ "$rc" -ne 0 ]; then
            echo "WARNING: command failed (exit $rc): $*" >&2
            FAILED_LOG+=("exit $rc: $*")
        fi
        return "$rc"
    fi
}

# try_run <cmd...> -- execute a command without adding failures to the final
# summary. Use this only for expected fallback probes.
try_run() {
    if $DRY_RUN; then
        echo "[dry-run] $*"
        DRY_LOG+=("$*")
        return 0
    fi

    "$@"
}

# plan <description> -- log a non-command action (file append, merge, etc.)
# in dry-run mode. Only called from inside dry-run branches.
plan() {
    echo "[dry-run] $*"
    DRY_LOG+=("$*")
}

wait_for_xcode_cli_tools() {
    local elapsed=0

    echo "Waiting for Xcode Command Line Tools installation..."
    until xcode-select -p &>/dev/null; do
        if [ "$elapsed" -ge "$XCODE_TIMEOUT_SECONDS" ]; then
            echo "Timed out waiting for Xcode Command Line Tools after $((XCODE_TIMEOUT_SECONDS / 60)) minutes." >&2
            echo "Finish or restart the installer, then rerun this script." >&2
            exit 1
        fi

        sleep "$XCODE_POLL_SECONDS"
        elapsed=$((elapsed + XCODE_POLL_SECONDS))
    done
}

print_failure_summary() {
    local failure

    if [ ${#FAILED_LOG[@]} -eq 0 ]; then
        return 0
    fi

    echo
    echo "=== Setup completed with failed commands ==="
    for failure in "${FAILED_LOG[@]}"; do
        echo "  - $failure"
    done
    return 1
}

write_file_if_missing() {
    local path="$1"

    if [ -e "$path" ]; then
        echo "Skipping existing file: $path"
        cat >/dev/null
        return 0
    fi

    if cat > "$path"; then
        echo "Created $path"
    else
        echo "WARNING: failed to write $path" >&2
        FAILED_LOG+=("failed to write $path")
        return 1
    fi
}

create_media_stack_template() {
    local stack_dir="$HOME/media-stack"
    local config_dir="$stack_dir/config"
    local service
    local services=(
        prowlarr
        sonarr
        radarr
        lidarr
        bazarr
        qbittorrent
        sabnzbd
        tautulli
        overseerr
        jellyseerr
        jellyfin
    )

    if $DRY_RUN; then
        plan "create Docker media stack template under $stack_dir"
        return
    fi

    if ! run mkdir -p "$config_dir"; then
        return
    fi

    for service in "${services[@]}"; do
        run mkdir -p "$config_dir/$service"
    done

    write_file_if_missing "$stack_dir/.env.example" <<'EOF'
# Copy this file to .env and edit it before running docker compose.
PUID=501
PGID=20
TZ=America/Denver
CONFIG_ROOT=./config
MEDIA_ROOT=/path/to/media/data
EOF

    write_file_if_missing "$stack_dir/.gitignore" <<'EOF'
.env
config/
EOF

    write_file_if_missing "$stack_dir/compose.yaml" <<'EOF'
name: media-stack

x-env: &env
  PUID: ${PUID}
  PGID: ${PGID}
  TZ: ${TZ}

services:
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    environment: *env
    volumes:
      - ${CONFIG_ROOT}/prowlarr:/config
    ports:
      - "9696:9696"
    restart: unless-stopped

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    environment: *env
    volumes:
      - ${CONFIG_ROOT}/sonarr:/config
      - ${MEDIA_ROOT}:/data
    ports:
      - "8989:8989"
    restart: unless-stopped

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    environment: *env
    volumes:
      - ${CONFIG_ROOT}/radarr:/config
      - ${MEDIA_ROOT}:/data
    ports:
      - "7878:7878"
    restart: unless-stopped

  lidarr:
    image: lscr.io/linuxserver/lidarr:latest
    environment: *env
    volumes:
      - ${CONFIG_ROOT}/lidarr:/config
      - ${MEDIA_ROOT}:/data
    ports:
      - "8686:8686"
    restart: unless-stopped

  bazarr:
    image: lscr.io/linuxserver/bazarr:latest
    environment: *env
    volumes:
      - ${CONFIG_ROOT}/bazarr:/config
      - ${MEDIA_ROOT}:/data
    ports:
      - "6767:6767"
    restart: unless-stopped

  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    environment:
      <<: *env
      WEBUI_PORT: 8080
    volumes:
      - ${CONFIG_ROOT}/qbittorrent:/config
      - ${MEDIA_ROOT}:/data
    ports:
      - "8080:8080"
      - "6881:6881"
      - "6881:6881/udp"
    restart: unless-stopped

  sabnzbd:
    image: lscr.io/linuxserver/sabnzbd:latest
    environment: *env
    volumes:
      - ${CONFIG_ROOT}/sabnzbd:/config
      - ${MEDIA_ROOT}:/data
    ports:
      - "8081:8080"
    restart: unless-stopped

  tautulli:
    image: lscr.io/linuxserver/tautulli:latest
    environment: *env
    volumes:
      - ${CONFIG_ROOT}/tautulli:/config
    ports:
      - "8181:8181"
    restart: unless-stopped

  # Request managers:
  # Use Overseerr for Plex, or Jellyseerr for Jellyfin.
  overseerr:
    image: sctx/overseerr:latest
    environment:
      TZ: ${TZ}
    volumes:
      - ${CONFIG_ROOT}/overseerr:/app/config
    ports:
      - "5055:5055"
    restart: unless-stopped

  jellyseerr:
    image: fallenbagel/jellyseerr:latest
    environment:
      TZ: ${TZ}
    volumes:
      - ${CONFIG_ROOT}/jellyseerr:/app/config
    ports:
      - "5056:5055"
    restart: unless-stopped

  jellyfin:
    image: lscr.io/linuxserver/jellyfin:latest
    environment: *env
    volumes:
      - ${CONFIG_ROOT}/jellyfin:/config
      - ${MEDIA_ROOT}:/data
    ports:
      - "8096:8096"
    restart: unless-stopped

# VPN note:
# If you want container-only VPN routing, add Gluetun later and route only
# the downloader through it. Do not put VPN secrets in this template.
EOF

    echo
    echo "Media stack template created at $stack_dir"
    echo "Next steps:"
    echo "  cp $stack_dir/.env.example $stack_dir/.env"
    echo "  edit $stack_dir/.env"
    echo "  cd $stack_dir && docker compose up -d"
    echo "No containers were started."
}

if $DRY_RUN; then
    echo "=== DRY RUN -- nothing will be installed or configured ==="
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
        wait_for_xcode_cli_tools
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
        # shellcheck disable=SC2016
        (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> "$HOME/.zprofile"
    fi
    eval "$(/opt/homebrew/bin/brew shellenv)"
    brew config

    echo "Updating Homebrew..."
    run brew update

    echo "Upgrading Homebrew..."
    run brew upgrade

    if ! command -v gum &>/dev/null; then
        echo "Installing gum..."
        run brew install gum
    fi
fi

abort() {
    echo
    echo "Setup aborted -- no further changes made."
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

# Every package picked in any menu, with cask: prefixes stripped.
SELECTED=()
INSTALL_CASKS=()
INSTALL_PIPX_PACKAGES=()
INSTALL_GEMS=()

was_picked() {
    command -v "$1" &>/dev/null && return 0
    local p
    for p in "${SELECTED[@]}"; do
        [ "$p" = "$1" ] && return 0
    done
    return 1
}

contains_item() {
    local needle="$1"; shift
    local item
    for item in "$@"; do
        [ "$item" = "$needle" ] && return 0
    done
    return 1
}

install_pipx_package() {
    local package="$1"
    try_run pipx install "$package" || run pipx upgrade "$package"
}

install_selected_package() {
    local name="$1"

    if contains_item "$name" "${INSTALL_CASKS[@]}"; then
        run brew install --cask "$name"
    elif contains_item "$name" "${INSTALL_PIPX_PACKAGES[@]}"; then
        install_pipx_package "$name"
    elif contains_item "$name" "${INSTALL_GEMS[@]}"; then
        run gem install "$name"
    else
        run brew install "$name"
    fi
}

select_and_install() {
    local header="$1"; shift
    local options=() defaults=()
    local item pkg def name
    INSTALL_CASKS=()
    INSTALL_PIPX_PACKAGES=()
    INSTALL_GEMS=()

    for item in "$@"; do
        pkg="${item%|*}"
        def="${item##*|}"
        case "$pkg" in
            cask:*)
                name="${pkg#cask:}"
                INSTALL_CASKS+=("$name")
                ;;
            pipx:*)
                name="${pkg#pipx:}"
                INSTALL_PIPX_PACKAGES+=("$name")
                ;;
            gem:*)
                name="${pkg#gem:}"
                INSTALL_GEMS+=("$name")
                ;;
            *)
                name="$pkg"
                ;;
        esac
        options+=("$name")
        [ "$def" = "y" ] && defaults+=("$name")
    done

    local selected_flag=()
    if [ ${#defaults[@]} -gt 0 ]; then
        local joined
        joined=$(IFS=','; echo "${defaults[*]}")
        selected_flag=(--selected="$joined")
    fi

    local chosen
    chosen=$(gum choose --no-limit --height 20 \
        --header "$header"$'\n'"x/space: toggle  enter: confirm  esc/ctrl+c: abort" \
        "${selected_flag[@]}" "${options[@]}" < /dev/tty) || abort

    while IFS= read -r name; do
        [ -z "$name" ] && continue
        SELECTED+=("$name")
        install_selected_package "$name"
    done <<< "$chosen"
}

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

    gum choose --no-limit --height 20 \
        --header "$header"$'\n'"x/space: toggle  enter: confirm  esc/ctrl+c: abort" \
        "${selected_flag[@]}" "${options[@]}" < /dev/tty
}

# Install Git (before oh-my-zsh plugins that need it)
if ! command -v git &>/dev/null; then
    echo "Installing Git..."
    run brew install git
else
    echo "git already installed!"
fi

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

# (font-fira-code-nerd-font is a Powerline-compatible Nerd Font.)
select_and_install "Terminal & Shell" \
    "cask:iterm2|y" \
    "cask:ghostty|n" \
    "cask:warp|n" \
    "tmux|y" \
    "zellij|n" \
    "vim|n" \
    "neovim|n" \
    "emacs|n" \
    "starship|n" \
    "zoxide|n" \
    "cask:font-fira-code-nerd-font|y"

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
        # zsh-syntax-highlighting must load last -- move it to the end if present
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
        # shellcheck disable=SC2016
        echo 'eval "$(starship init zsh)"' >> "$HOME/.zshrc"
        echo "Added starship init to ~/.zshrc"
    fi
fi
if was_picked zoxide && ! grep -q 'zoxide init' "$HOME/.zshrc" 2>/dev/null; then
    if $DRY_RUN; then
        plan "append zoxide init to ~/.zshrc"
    else
        # shellcheck disable=SC2016
        echo 'eval "$(zoxide init zsh)"' >> "$HOME/.zshrc"
        echo "Added zoxide init to ~/.zshrc"
    fi
fi

# CLI Tools -- command-line utilities (includes the old "Useful Binaries")
select_and_install "CLI Tools" \
    "lazygit|y" \
    "gh|y" \
    "jq|y" \
    "shellcheck|y" \
    "delta|y" \
    "fzf|y" \
    "bat|y" \
    "eza|y" \
    "ripgrep|y" \
    "fd|y" \
    "btop|y" \
    "wget|y" \
    "imagemagick|y" \
    "xz|y" \
    "bfg|n" \
    "nmap|n" \
    "libpq|n"

# Use delta as git's pager only if it's actually installed (or just picked)
if was_picked delta; then
    run git config --global core.pager delta
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
    echo "Installing pipx..."
    run brew install pipx
    run pipx ensurepath
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
            # shellcheck disable=SC2016
            echo 'export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"' >> "$HOME/.zprofile"
        fi
    fi
fi

if echo "$LANGS" | grep -qx ruby; then
    RUBY_BIN_PATH="/opt/homebrew/opt/ruby/bin"
    USE_BREW_RUBY=false
    if command -v brew &>/dev/null; then
        BREW_RUBY_PREFIX="$(brew --prefix ruby 2>/dev/null)"
        [ -n "$BREW_RUBY_PREFIX" ] && RUBY_BIN_PATH="$BREW_RUBY_PREFIX/bin"
    fi

    if ! command -v ruby &>/dev/null || [ "$(which ruby)" = "/usr/bin/ruby" ]; then
        USE_BREW_RUBY=true
        echo "Installing Ruby..."
        run brew install ruby
        if ! grep -q 'ruby/bin' "$HOME/.zprofile" 2>/dev/null; then
            if $DRY_RUN; then
                plan "add brew ruby to PATH in ~/.zprofile"
            else
                echo "Adding the brew ruby path to shell config..."
                echo "export PATH=\"$RUBY_BIN_PATH:\$PATH\"" >> "$HOME/.zprofile"
            fi
        fi
    else
        echo "Ruby already installed!"
    fi

    if $USE_BREW_RUBY && [ -d "$RUBY_BIN_PATH" ]; then
        export PATH="$RUBY_BIN_PATH:$PATH"
    fi
fi

# Development Apps (GUI)
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

# install_ai_tool <menu label> <npm package> -- installs if selected above
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

# Claude Code Plugins -- only when Claude Code was selected above
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
    "cask:bitwarden|n" \
    "cask:figma|n" \
    "cask:tailscale|n" \
    "cask:the-unarchiver|n" \
    "cask:appcleaner|n" \
    "cask:stats|n" \
    "cask:vlc|n" \
    "cask:spotify|y"

# Media archival, discovery, and sharing -- not for pirating copyrighted material
if confirm "Install media archival / discovery / sharing tools?" --default=No; then
    select_and_install "Media Tools" \
        "cask:mullvad-vpn|n" \
        "cask:transmission|n" \
        "cask:plex|n" \
        "cask:plex-media-server|n" \
        "cask:jellyfin|n" \
        "cask:jellyfin-media-player|n" \
        "cask:sabnzbd|n" \
        "bazarr|n" \
        "nzbget|n"

    echo "NOTE: Homebrew currently marks qBittorrent and the Sonarr/Radarr/Lidarr/Prowlarr casks as deprecated for Gatekeeper issues."
    echo "NOTE: Use Docker/OrbStack or manual downloads for the *arr suite, Readarr, Overseerr, and Tautulli."
fi

if confirm "Create Docker media stack template?" --default=No; then
    create_media_stack_template
fi

# CTF tools, for when you want to get your Mr. Robot on
if confirm "Install CTF / security tools?" --default=No; then
    CTF_TOOLS=(
        "ghidra|n"
        "radare2|n"
        "binwalk|n"
        "binutils|n"
        "foremost|n"
        "john|n"
        "hashcat|n"
        "fcrackzip|n"
        "hydra|n"
        "sqlmap|n"
        "ffuf|n"
        "gobuster|n"
        "nikto|n"
        "aircrack-ng|n"
        "cask:wireshark|n"
        "tcpflow|n"
        "tcpreplay|n"
        "socat|n"
        "dns2tcp|n"
        "pngcheck|n"
    )

    if echo "$LANGS" | grep -qx python; then
        CTF_TOOLS+=(
            "pipx:volatility3|n"
            "pipx:ROPGadget|n"
            "pipx:ropper|n"
            "pipx:oletools|n"
            "pipx:wafw00f|n"
            "pipx:frida-tools|n"
            "pipx:impacket|n"
            "pipx:ciphey|n"
            "pipx:pwncat-cs|n"
        )
    fi

    if echo "$LANGS" | grep -qx ruby; then
        CTF_TOOLS+=(
            "gem:zsteg|n"
            "gem:wpscan|n"
            "gem:evil-winrm|n"
        )
    fi

    select_and_install "CTF Tools" "${CTF_TOOLS[@]}"
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
    echo "=== Dry run complete -- would have run: ==="
    if [ ${#DRY_LOG[@]} -eq 0 ]; then
        echo "(nothing selected)"
    else
        printf '  %s\n' "${DRY_LOG[@]}"
    fi
else
    echo "Running brew cleanup..."
    run brew cleanup

    if print_failure_summary; then
        echo "You're done!"
    else
        exit 1
    fi
fi
