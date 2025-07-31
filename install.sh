#!/usr/bin/env bash
set -e

echo "┌────────────────────┐"
echo "│  Save's Dots Setup │"
echo "└────────────────────┘"
echo

# ── Choose dotfiles repo ───────────────────────────────
echo "Choices:"
echo "1) Save's Dots (default)"
echo "2) Jomo's Dots (for testing and other reasons)"
echo "3) Partial Installation (choose which configs to install)"
read -rp "Enter choice [1/2/3]: " choice

case "$choice" in
  1|"")
    gh_repo_url="https://github.com/savew-dots/dots"
    ;;
  2)
    gh_repo_url="https://github.com/xeome/dots"
    ;;
  3)
    gh_repo_url="https://github.com/savew-dots/.github"
    ;;
  *)
    echo "❌ Invalid choice. Defaulting to Save's Dots."
    gh_repo_url="https://github.com/savew-dots/.github"
    choice=1
    ;;
esac

# ── Check if GitHub repo is reachable ──────────────────
repo_check() {
  echo
  echo "🌐 Checking GitHub repo URL..."
  gh_status=$(curl -o /dev/null -s -w "%{http_code}" "$gh_repo_url")
  if [ "$gh_status" -eq 200 ]; then
    echo "✅ GitHub repo is reachable."
  else
    echo -e "❌ GitHub repo is NOT reachable :( \nExiting."
    exit 1
  fi
}

# ── Some important variables ──────────────────
CONFIGS=(
  "alacritty"
  "gtklock"
  "hypr"
  "k9s"
  "matugen"
  "mpv"
  "rofi"
  "swayosd"
  "wallpapers"
  "waybar"
  "wtf"
  "zathura"
  "zsh"
)

INSTALL_DIR="$HOME/.config"

# ── Check if system is Arch-based ──────────────────────
check_distro() {
  id=$(grep '^ID=' /etc/os-release | head -n1 | sed 's/^ID=//; s/"//g')
  id_like=$(grep '^ID_LIKE=' /etc/os-release | head -n1 | sed 's/^ID_LIKE=//; s/"//g')

  if [[ "$id" == "arch" ]] || [[ "$id_like" == *arch* ]]; then
    echo "✅ Distribution is Arch or Arch-based. Continuing setup..."
  else
    echo "❌ Distribution is not Arch or Arch-based. This script is intended for Arch-based systems only."
    exit 1
  fi
}

# ── Detect or install AUR helper ───────────────────────
aur_helper() {
  echo "🔍 Checking for AUR helper (yay or paru)..."
  if command -v yay &> /dev/null; then
    echo "✅ AUR helper 'yay' detected."
    aur_helper="yay"
  elif command -v paru &> /dev/null; then
    echo "✅ AUR helper 'paru' detected."
    aur_helper="paru"
  else
    echo "⚠️  No AUR helper found on the system."
    echo "📦 Installing prerequisites: base-devel and git..."
    sudo pacman -S --needed base-devel git

    echo "⬇️  Cloning 'yay' from the AUR..."
    cd "$(mktemp -d)" || exit
    git clone https://aur.archlinux.org/yay.git
    cd yay || exit

    echo "⚙️  Building and installing 'yay'..."
    makepkg -si

    aur_helper="yay"
    echo "✅ AUR helper 'yay' installed successfully."
  fi
}

# ── Install packages from GitHub list ──────────────────
install_pkgs() {
  echo "⬇️  Downloading package list from GitHub..."
  cd "$(mktemp -d)" || exit
  wget https://raw.githubusercontent.com/savew-dots/.github/refs/heads/main/assets/pkgs

  echo "📦 Installing packages using $aur_helper..."
  $aur_helper -S --needed - < pkgs
}

# ── Install dots ──────────────────
install() {
  if [[ "$choice" == "1" || -z "$choice" ]]; then
    for config in "${CONFIGS[@]}"; do
      echo "⚙️ Installing $config..."

      repo_url="https://github.com/savew-dots/$config"
      target="$INSTALL_DIR/$config"

      if [[ ! -d "$target/.git" ]]; then
        echo "📥 Cloning $repo_url → $target"
        rm -rf "$target"
        git clone "$repo_url" "$target"
      else
        echo "↻ Updating $config..."
        git -C "$target" pull --ff-only
      fi
    done
  elif [[ "$choice" == "2" ]]; then
    echo "⚙️ Installing Jomo's dots..."
    echo "🎯 Setting up dotfiles with chezmoi..."
    chezmoi init "$gh_repo_url"
    chezmoi apply -v
  elif [[ "$choice" == "3" ]]; then
    echo "⚙️ Partial installation mode"
    echo "Available configs (type numbers separated by spaces, or 'q' to quit):"
    for i in "${!CONFIGS[@]}"; do
      printf "%2d) %s\n" $((i+1)) "${CONFIGS[$i]}"
    done

    read -rp "Select configs to install: " selections

    if [[ "$selections" == "q" ]]; then
      echo "👋 Exiting partial installation."
      exit 0
    fi

    for sel in $selections; do
      index=$((sel-1))
      config="${CONFIGS[$index]}"

      if [[ -n "$config" ]]; then
        repo_url="https://github.com/savew-dots/$config"
        target="$INSTALL_DIR/$config"

        echo "⚙️ Installing $config..."
        if [[ ! -d "$target/.git" ]]; then
          echo "📥 Cloning $repo_url → $target"
          rm -rf "$target"
          git clone "$repo_url" "$target"
        else
          echo "↻ Updating $config..."
          git -C "$target" pull --ff-only
        fi
      else
        echo "❌ Invalid selection: $sel"
      fi
    done
  else
    echo "❌ Invalid choice. Please select 1, 2, or 3."
    exit 1
  fi
}

# ── Download fonts ─────────────────────────
install_fonts() {
  echo "🔤 Downloading fonts..."

  sf_pro_url="https://files.savew.dev/sf-pro.zip"
  sf_pro_fallback="https://files.xeome.dev/sf-pro.zip"

  echo "🌐 Checking SF Pro font URL..."
  status=$(wget --server-response --spider "$sf_pro_url" 2>&1 | awk '/HTTP\// {print $2; exit}')
  if [ "$status" -eq 200 ]; then
    echo "✅ SF Pro font URL is reachable. Downloading..."
    wget "$sf_pro_url"
  else
    echo "⚠️  SF Pro main URL failed. Checking fallback URL..."
    fallback_status=$(wget --server-response --spider "$sf_pro_fallback" 2>&1 | awk '/HTTP\// {print $2; exit}')
    if [ "$fallback_status" -eq 200 ]; then
        echo "✅ Fallback URL is reachable. Downloading fallback font..."
        wget "$sf_pro_fallback"
    else
        echo "❌ Both main and fallback URLs are unreachable. Exiting."
        exit 1
    fi
  fi
}

# ── Extract and refresh fonts ──────────────────────────
extract_fonts() {
  echo "🗂️  Extracting fonts to ~/.fonts..."
  mkdir -p ~/.fonts
  bsdtar -xf sf-pro.zip -C ~/.fonts

  echo "🌀 Refreshing font cache..."
  fc-cache -frv

  echo "🧹 Cleaning up downloaded font archives..."
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

if [[ "$choice" == "3" ]]; then
  subconfig_install
else
  main
fi
