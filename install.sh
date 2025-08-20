#!/usr/bin/env bash
set -e

if command -v gum &> /dev/null; then
  echo "gum detected."
else
  echo "gum not detected, installing it..."
  sudo pacman -S gum
fi

clear

gum style \
        --foreground 147 --border-foreground 153 --border double \
        --align center --width 50 --margin "1 2" --padding "2 4" \
        "Welcome to" "Save's Dotfiles"

# ── Choose dotfiles repo ───────────────────────────────
choice=$(gum choose --header "Select one of the following options:" \
  "Save's Dots (default)" \
  "Jomo's Dots (for testing and other reasons)" \
  "Partial Installation (choose which configs to install)")

case "$choice" in
  "Save's Dots (default)"|"")
    gh_repo_url="https://github.com/savew-dots/.github"
    ;;
  "Jomo's Dots (for testing and other reasons)")
    gh_repo_url="https://github.com/xeome/dots"
    ;;
  "Partial Installation (choose which configs to install)")
    gh_repo_url="https://github.com/savew-dots/.github"
    ;;
  *)
    gum log --structured --level error "Unexpected choice, continuing with $choice"
    gh_repo_url="https://github.com/savew-dots/.github"
    ;;
esac

# ── Check if GitHub repo is reachable ──────────────────
repo_check() {
  gum spin --spinner dot --title "Checking GitHub repo..." -- sleep 3
  gh_status=$(curl -o /dev/null -s -w "%{http_code}" "$gh_repo_url")
  if [ "$gh_status" -eq 200 ]; then
    gum log --structured --level info "GitHub repo reachable!"
  else
    gum log --structured --level error "GitHub repo not found :("
    exit 1
  fi
}

# ── Some important variables ──────────────────
INSTALL_DIR="$HOME/.config"

# ── Check if system is Arch-based ──────────────────────
check_distro() {
  id=$(grep '^ID=' /etc/os-release | head -n1 | sed 's/^ID=//; s/"//g')
  id_like=$(grep '^ID_LIKE=' /etc/os-release | head -n1 | sed 's/^ID_LIKE=//; s/"//g')

  if [[ "$id" == "arch" ]] || [[ "$id_like" == *arch* ]]; then
    gum log --structured --level info "Distribution is Arch or Arch-based. Continuing setup..."
  else
    gum log --structured --level error "Distribution is not Arch or Arch-based. This script is intended for Arch-based systems only :( "
    exit 1
  fi
}

# ── Detect or install AUR helper ───────────────────────
aur_helper() {
  echo "🔍 Checking for AUR helper (yay or paru)..."
  if command -v yay &> /dev/null; then
    gum log --structured --level info "AUR Helper 'yay' found."
    aur_helper="yay"
  elif command -v paru &> /dev/null; then
    gum log --structured --level info "AUR Helper 'paru' found."
    aur_helper="paru"
  else
    gum log --structured --level error "No AUR helper found on the system!"
    gum log --structured --level debug "Installing prerequisites: base-devel and git..."
    sudo pacman -S --needed base-devel git

    gum log --structured --level info "Cloning 'yay' from the AUR..."
    cd "$(mktemp -d)" || exit
    git clone https://aur.archlinux.org/yay.git
    cd yay || exit

    gum log --structured --level info "Building and installing 'yay'..."
    makepkg -si

    aur_helper="yay"
    gum log --structured --level info "AUR helper 'yay' installed successfully."
  fi
}

# ── Install packages from GitHub list ──────────────────
install_pkgs() {
  gum log --structured --level info "Downloading package list from GitHub..."
  cd "$(mktemp -d)" || exit
  wget https://raw.githubusercontent.com/savew-dots/.github/refs/heads/main/assets/pkgs

  gum log --structured --level info "Installing packages using $aur_helper..."
  $aur_helper -S --needed - < pkgs
}

# ── Install dots ──────────────────
install() {
  if [[ "$choice" == "Save's Dots (default)" || -z "$choice" ]]; then
    for config in "${CONFIGS[@]}"; do
      gum log --structured --level info "Installing $config..."

      repo_url="https://github.com/savew-dots/$config"
      target="$INSTALL_DIR/$config"

      if [[ ! -d "$target/.git" ]]; then
        gum log --structured --level info "Cloning $repo_url → $target"
        rm -rf "$target"
        git clone "$repo_url" "$target"
      else
        gum log --structured --level info "Updating $config..."
        git -C "$target" pull --ff-only
      fi
    done
  elif [[ "$choice" == "Jomo's Dots (for testing and other reasons)" ]]; then
    gum log --structured --level info "Installing Jomo's dots..."
    gum log --structured --level info "Setting up dotfiles with chezmoi..."
    chezmoi init "$gh_repo_url"
    chezmoi apply -v
  elif [[ "$choice" == "Partial Installation (choose which configs to install)" ]]; then
    gum log --structured --level info "Partial installation mode ready!"
    config=$(gum choose --header "Available configs:" \
      "alacritty" \
      "gtklock" \
      "hypr" \
      "k9s" \
      "matugen" \
      "mpv" \
      "rofi" \
      "swayosd" \
      "wallpapers" \
      "waybar" \
      "zathura" \
      "zsh")
    
    if [[ -n "$config" ]]; then
      repo_url="https://github.com/savew-dots/$config"
      target="$INSTALL_DIR/$config"

      gum log --structured --level info "Installing $config..."
      if [[ ! -d "$target/.git" ]]; then
        gum log --structured --level info "Cloning $repo_url → $target"
        rm -rf "$target"
        git clone "$repo_url" "$target"
      else
        gum log --structured --level info "Updating $config..."
        git -C "$target" pull --ff-only
      fi
    else
      gum log --structured --level error "Invalid selection: $config"
    fi
  else
    exit 1
  fi
}

# ── Download fonts ─────────────────────────
install_fonts() {
  gum log --structured --level info "Downloading fonts..."

  sf_pro_url="https://files.savew.dev/sf-pro.zip"
  sf_pro_fallback="https://files.xeome.dev/sf-pro.zip"

  gum spin --spinner dot --title "Checking SF Pro font URL..." -- sleep 3
  status=$(wget --server-response --spider "$sf_pro_url" 2>&1 | awk '/HTTP\// {print $2; exit}')
  if [ "$status" -eq 200 ]; then
    gum log --structured --level info "SF Pro font URL is reachable. Downloading..."
    wget "$sf_pro_url"
  else
    gum log --structured --level error "SF Pro main URL failed. Checking fallback URL..."
    fallback_status=$(wget --server-response --spider "$sf_pro_fallback" 2>&1 | awk '/HTTP\// {print $2; exit}')
    if [ "$fallback_status" -eq 200 ]; then
        gum log --structured --level info "Fallback URL is reachable. Downloading fallback font..."
        wget "$sf_pro_fallback"
    else
        gum log --structured --level error "Both main and fallback URLs are unreachable. Exiting."
        exit 1
    fi
  fi
}

# ── Extract and refresh fonts ──────────────────────────
extract_fonts() {
  gum log --structured --level info "Extracting fonts to ~/.fonts..."
  mkdir -p ~/.fonts
  bsdtar -xf sf-pro.zip -C ~/.fonts

  gum spin --spinner dot --title "Refreshing font cache..." -- sleep 2
  fc-cache -frv

  gum log --structured --level info "Cleaning up downloaded font archives..."
  rm "sf-pro.zip"
}

# ── Installing System ───────────────────────────────────────────────
main_install() {
  repo_check
  check_distro
  aur_helper
  install_pkgs
  install
  install_fonts
  extract_fonts
  echo "✅ All done! jomolayana..."
}

subconfig_install() {
  repo_check
  install
  echo "✅ All done! jomolayana..."
}

if [[ "$choice" == "Partial Installation (choose which configs to install)" ]]; then
  subconfig_install
else
  main_install
fi
