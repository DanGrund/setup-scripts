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

chflags nohidden ~/Library                                                          # Show Library Folder in Finder
defaults write com.apple.finder AppleShowAllFiles YES                               # Show Hidden Files in Finder
defaults write com.apple.finder ShowPathbar -bool true                              # Show Path Bar in Finder
defaults write com.apple.finder ShowStatusBar -bool true                            # Show Status Bar in Finder
sudo systemsetup -setcomputersleep Off > /dev/null                                  # Never go into computer sleep mode
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40 # Increase sound quality for Bluetooth headphones/headsets
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3                            # Enable keyboard access for all controls (e.g. enable Tab in modal dialogs)
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false                  # Disable press-and-hold for keys in favor of key repeat
defaults write com.apple.screencapture type -string "png"                           # Save screenshots in PNG format (other options: BMP, GIF, JPG, PDF, TIFF)
defaults write com.apple.screencapture disable-shadow -bool true                    # Disable shadow in screenshots
defaults write NSGlobalDomain AppleFontSmoothing -int 2                             # Enable subpixel font rendering on non-Apple LCDs
chflags nohidden ~/Library                                                          # Show the ~/Library folder

# Set a blazingly fast keyboard repeat rate
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Disable Notification Center and remove the menu bar icon
# launchctl unload -w /System/Library/LaunchAgents/com.apple.notificationcenterui.plist 2> /dev/null 

# Enable HiDPI display modes (requires restart)
# sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true

echo "------------------------------"


# Check for Homebrew, and then install it
if test ! $(which brew); then
    echo "Installing homebrew..."
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    echo "Homebrew installed successfully"
else
    echo "Homebrew already installed!"
fi

brew config

# Updating Homebrew.
echo "Updating Homebrew..."
brew update

# Upgrade any already-installed formulae.
echo "Upgrading Homebrew..."
brew upgrade

# Install iTerm2
echo "Installing iTerm2..."
brew cask install iterm2

# Update the Terminal
# Install oh-my-zsh
echo "Installing oh-my-zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

# Install Git
if test ! $(which git); then
    echo "Installing Git..."
    brew install git
else
    echo "git already installed!"
fi

git config --global user.name "Dan Grund"
git config --global user.email "hello@dangrund.com"

# Install Python
echo "Installing python..."
brew install python
brew install python3

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

# Install Powerline fonts: all sorts of handy typefaces 
echo "Installing Powerline fonts..."
git clone https://github.com/powerline/fonts.git
cd fonts
sh -c ./install.sh
cd ..
rm -rf fonts

# Development Apps
brew install node
brew cask install --appdir="/Applications" visual-studio-code
brew cask install --appdir="/Applications" webstorm
brew cask install --appdir="/Applications" dbeaver-community
brew cask install --appdir="/Applications" docker
brew cask install --appdir="/Applications" postman
brew cask install --appdir="/Applications" pgadmin4
brew install libpq

# Productivity Apps
brew cask install --appdir="/Applications" firefox
brew cask install --appdir="/Applications" google-chrome
brew cask install --appdir="/Applications" slack
brew cask install --appdir="/Applications" discord
brew cask install --appdir="/Applications" lastpass
brew cask install --appdir="/Applications" caffeine
brew cask install --appdir="/Applications" notion
brew cask install --appdir="/Applications" sketch

# Other Stuff
brew cask install --appdir="/Applications" sketchup
brew cask install --appdir="/Applications" spotify

# Useful Binaries
brew cask install rectangle     # window management utility, https://github.com/rxhanson/Rectangle
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
