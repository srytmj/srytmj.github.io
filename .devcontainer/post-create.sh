#!/usr/bin/env bash

# Clean old Node (optional but safe)
sudo apt remove -y nodejs npm
sudo apt autoremove -y

# Install Node 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Build Chirpy assets
if [ -f package.json ]; then
  npm install
  npm run build
fi

# Install dependencies for shfmt extension
curl -sS https://webi.sh/shfmt | sh &>/dev/null

# Add OMZ plugins (safe clone)
[ ! -d ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting ] && \
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

[ ! -d ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions ] && \
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions

# Enable plugins
sed -i -E "s/^(plugins=\()(git)(\))/\1\2 zsh-syntax-highlighting zsh-autosuggestions\3/" ~/.zshrc

# Avoid git log using less
echo -e "\nunset LESS" >> ~/.zshrc
