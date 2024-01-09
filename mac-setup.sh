#!/usr/bin/env bash

# Copied bits and pieces from donnemartin/dev-setup, the stuff I need to get up and running on a new mac
# To Execute, run: 
# curl -fsSL https://raw.githubusercontent.com/DanGrund/setup-scripts/main/mac-setup.sh | sh

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
# Install Xcode command line tools
xcode-select --install

# OSX configs 
echo "------------------------------"
echo "Updating system prefrences"

#defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40 # Increase sound quality for Bluetooth headphones/headsets
#defaults write NSGlobalDomain AppleKeyboardUIMode -int 3                            # Enable keyboard access for all controls (e.g. enable Tab in modal dialogs)
defaults write com.apple.screencapture type -string "png"                           # Save screenshots in PNG format (other options: BMP, GIF, JPG, PDF, TIFF)
defaults write com.apple.screencapture disable-shadow -bool true                    # Disable shadow in screenshots
#defaults write NSGlobalDomain AppleFontSmoothing -int 2                             # Enable subpixel font rendering on non-Apple LCDs

echo "------------------------------"

# Check for Homebrew, and then install it
if test ! $(which brew); then
    echo "Installing homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo "Homebrew installed successfully"
else
    echo "Homebrew already installed!"
fi
(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> /Users/dangrund/.zprofile
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
brew install iterm2 --cask

echo "Installing TMUX..."
brew install tmux

# Update the Terminal
# Install oh-my-zsh
echo "Installing oh-my-zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions

# Install Git
if test ! $(which git); then
    echo "Installing Git..."
    brew install git
else
    echo "git already installed!"
fi

git config --global user.name "Dan Grund"
git config --global user.email "hello@dangrund.com"
git config --global pager.branch false

# Install Python
echo "Installing python..."
brew install python

# Install ruby
if test ! $(which ruby); then
    echo "Installing Ruby..."
    brew install ruby
    echo "Adding the brew ruby path to shell config..."
    echo 'export PATH="/usr/local/opt/ruby/bin:$PATH"' >>~/.bash_profile
else
    echo "Ruby already installed!"
fi

# Install vim
echo "Installing vim..."
brew install vim

# Install Powerline fonts: needed for the powerline theming in OhMyZSH
echo "Installing Powerline fonts..."
git clone https://github.com/powerline/fonts.git
cd fonts
sh -c ./install.sh
cd ..
rm -rf fonts

# Install firaCode, handy ligature-enabled monospaced type for your IDE
brew tap homebrew/cask-fonts
brew install font-fira-code --cask

# Development Apps
brew install node
brew install --appdir="/Applications" visual-studio-code --cask
brew install --appdir="/Applications" webstorm --cask
brew install --appdir="/Applications" dbeaver-community --cask
brew install --appdir="/Applications" docker --cask
brew install --appdir="/Applications" postman --cask
brew install --appdir="/Applications" pgadmin4 --cask
brew install libpq

# Productivity Apps
brew install --appdir="/Applications" firefox --cask
brew install --appdir="/Applications" google-chrome --cask
brew install --appdir="/Applications" slack --cask
brew install --appdir="/Applications" discord --cask
brew install --appdir="/Applications" notion --cask
brew install --appdir="/Applications" rectangle --cask

# Other Stuff
# brew cask install --appdir="/Applications" sketchup
brew install --appdir="/Applications" spotify --cask

# Useful Binaries
brew install speedtest_cli      # ookla in your CLI, so you can always complain about comcast
brew install nmap               # diagnose network connections
brew install wget               # downloads

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
# brew install homebrew/x11/xpdf
# brew install xz

# Remove outdated versions from the cellar.
echo "Running brew cleanup..."
brew cleanup
echo "You're done!"
