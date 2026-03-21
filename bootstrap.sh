#!/usr/bin/env bash
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    exec sudo -E bash "$0" "$@"
  fi
}

detect_distro() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "${ID:-unknown}"
  else
    echo "unknown"
  fi
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

as_user() {
  local target="${SUDO_USER:-$USER}"
  sudo -u "$target" -H bash -lc "$*"
}

user_home() {
  local target="${SUDO_USER:-$USER}"
  getent passwd "$target" | cut -d: -f6
}

ensure_whiptail() {
  if have_cmd whiptail; then return 0; fi

  local distro; distro="$(detect_distro)"
  case "$distro" in
    arch|endeavouros|manjaro)
      pacman -Sy --needed --noconfirm libnewt || true
      ;;
    debian|ubuntu|linuxmint|pop)
      apt-get update
      apt-get install -y whiptail || true
      ;;
    fedora)
      dnf -y install newt || true
      ;;
    void)
      xbps-install -Sy newt || true
      ;;
    *)
      ;;
  esac
}

choose_components() {
  local choices=()

  if have_cmd whiptail; then
    local res
    res="$(whiptail --title "Dotfiles bootstrap" \
      --checklist "Select what to install/setup:" 22 86 12 \
      "BASE"     "i3 essentials (i3status/i3lock/xss-lock/dex/nm-applet/polkit/picom/feh)" ON \
      "APPS"     "alacritty + dmenu + thunar" ON \
      "BRAVE"    "install Brave browser (where supported)" OFF \
      "FISH"     "install fish + set as default login shell" ON \
      "LY"       "install + enable ly display manager (best effort per distro)" ON \
      "DOTFILES" "deploy configs from ./home into your \$HOME (copy + backup)" ON \
      "WRAPPER"  "install ~/.local/bin/browser wrapper" ON \
      3>&1 1>&2 2>&3
    )" || true

    res="${res//\"/}"
    for t in $res; do choices+=("$t"); done
  else
    echo "whiptail not available; using simple prompts."
    read -r -p "Install BASE? [Y/n] " a; [[ "${a:-Y}" =~ ^[Nn]$ ]] || choices+=("BASE")
    read -r -p "Install APPS? [Y/n] " a; [[ "${a:-Y}" =~ ^[Nn]$ ]] || choices+=("APPS")
    read -r -p "Install Brave? [y/N] " a; [[ "${a:-N}" =~ ^[Yy]$ ]] && choices+=("BRAVE")
    read -r -p "Install+default fish? [Y/n] " a; [[ "${a:-Y}" =~ ^[Nn]$ ]] || choices+=("FISH")
    read -r -p "Install+enable ly? [Y/n] " a; [[ "${a:-Y}" =~ ^[Nn]$ ]] || choices+=("LY")
    read -r -p "Deploy dotfiles from ./home? [Y/n] " a; [[ "${a:-Y}" =~ ^[Nn]$ ]] || choices+=("DOTFILES")
    read -r -p "Install browser wrapper? [Y/n] " a; [[ "${a:-Y}" =~ ^[Nn]$ ]] || choices+=("WRAPPER")
  fi

  printf '%s\n' "${choices[@]}"
}

selected() {
  local needle="$1"; shift
  local x
  for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done
  return 1
}

# ----------------------------
# Install per distro
# ----------------------------
install_arch() {
  local pkgs=()
  local base_pkgs=(i3-wm i3status i3lock xss-lock dex network-manager-applet polkit-gnome picom feh)
  local apps_pkgs=(alacritty dmenu thunar)
  local fish_pkgs=(fish)
  local ly_pkgs=(ly)
  local tools_pkgs=(git curl ca-certificates)

  selected BASE "$@" && pkgs+=("${base_pkgs[@]}")
  selected APPS "$@" && pkgs+=("${apps_pkgs[@]}")
  selected FISH "$@" && pkgs+=("${fish_pkgs[@]}")
  selected LY   "$@" && pkgs+=("${ly_pkgs[@]}")
  pkgs+=("${tools_pkgs[@]}")

  pacman -Sy --needed --noconfirm "${pkgs[@]}"

  if selected BASE "$@"; then
    echo "NOTE (Arch): input-remapper is typically AUR. If you want it:"
    echo "  yay -S input-remapper"
  fi

  if selected BRAVE "$@"; then
    echo "NOTE (Arch): Brave is typically AUR (brave-bin)."
    if have_cmd yay; then
      as_user "yay -S --needed --noconfirm brave-bin || true"
    else
      echo "Install yay then run: yay -S brave-bin"
    fi
  fi
}

install_debian_like() {
  apt-get update

  local pkgs=()
  local base_pkgs=(i3 i3status i3lock xss-lock dex network-manager-gnome policykit-1-gnome picom feh)
  local apps_pkgs=(alacritty dmenu thunar)
  local fish_pkgs=(fish)
  local tools_pkgs=(git curl gnupg ca-certificates)

  selected BASE "$@" && pkgs+=("${base_pkgs[@]}")
  selected APPS "$@" && pkgs+=("${apps_pkgs[@]}")
  selected FISH "$@" && pkgs+=("${fish_pkgs[@]}")
  pkgs+=("${tools_pkgs[@]}")

  apt-get install -y "${pkgs[@]}"

  if selected BASE "$@"; then
    apt-get install -y input-remapper input-remapper-gtk input-remapper-daemon || true
  fi

  if selected LY "$@"; then
    # Some releases have it, some don't.
    apt-get install -y ly || echo "NOTE (Debian/Ubuntu): 'ly' not available via apt on this release; skipping install."
  fi

  if selected BRAVE "$@"; then
    if ! have_cmd brave-browser; then
      echo "Installing Brave (Debian/Ubuntu) via official repository..."
      curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
        > /etc/apt/sources.list.d/brave-browser-release.list
      apt-get update
      apt-get install -y brave-browser || true
    fi
  fi
}

install_fedora() {
  local pkgs=()
  local base_pkgs=(i3 i3status i3lock xss-lock nm-applet polkit-gnome picom feh)
  local dex_pkg=(dex-autostart)
  local apps_pkgs=(alacritty dmenu thunar)
  local fish_pkgs=(fish)
  local tools_pkgs=(git curl ca-certificates)

  selected BASE "$@" && pkgs+=("${base_pkgs[@]}" "${dex_pkg[@]}")
  selected APPS "$@" && pkgs+=("${apps_pkgs[@]}")
  selected FISH "$@" && pkgs+=("${fish_pkgs[@]}")
  pkgs+=("${tools_pkgs[@]}")

  dnf -y install "${pkgs[@]}"

  if selected BASE "$@"; then
    dnf -y install input-remapper || true
  fi

  if selected LY "$@"; then
    # ly is often via COPR on Fedora
    dnf -y install dnf-plugins-core || true
    # Try a known COPR first; fallback to another common one
    dnf -y copr enable dhalucario/ly || dnf -y copr enable fnux/ly || true
    dnf -y install ly || echo "NOTE (Fedora): couldn't install ly via COPR; skipping."
  fi

  if selected BRAVE "$@"; then
    if ! have_cmd brave-browser; then
      echo "Installing Brave (Fedora) via official repository..."
      dnf -y install dnf-plugins-core || true
      dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo || true
      dnf -y install brave-browser || true
    fi
  fi
}

install_void() {
  local pkgs=()
  local base_pkgs=(i3 i3status i3lock xss-lock dex NetworkManager-applet polkit-gnome picom feh)
  local apps_pkgs=(alacritty dmenu thunar)
  local fish_pkgs=(fish)
  local tools_pkgs=(git curl ca-certificates)

  selected BASE "$@" && pkgs+=("${base_pkgs[@]}")
  selected APPS "$@" && pkgs+=("${apps_pkgs[@]}")
  selected FISH "$@" && pkgs+=("${fish_pkgs[@]}")
  pkgs+=("${tools_pkgs[@]}")

  xbps-install -Sy "${pkgs[@]}"

  if selected LY "$@"; then
    xbps-install -y ly || echo "NOTE (Void): ly not in official repos; you’ll likely need xbps-src/templates."
  fi

  if selected BASE "$@"; then
    echo "NOTE (Void): input-remapper may not be in official repos; you might need xbps-src or alternatives."
  fi

  if selected BRAVE "$@"; then
    echo "NOTE (Void): Brave is not a clean official install; you’ll likely need xbps-src templates (3rd-party)."
  fi
}

# ----------------------------
# Setup actions
# ----------------------------
install_browser_wrapper() {
  local home_dir; home_dir="$(user_home)"
  [[ -n "$home_dir" ]] || die "Could not determine user home"

  install -d -m 0755 "$home_dir/.local/bin"
  cat > "$home_dir/.local/bin/browser" <<'EOF'
#!/usr/bin/env bash
set -e
if command -v brave-browser >/dev/null 2>&1; then
  exec brave-browser "$@"
elif command -v brave >/dev/null 2>&1; then
  exec brave "$@"
elif command -v firefox >/dev/null 2>&1; then
  exec firefox "$@"
elif command -v xdg-open >/dev/null 2>&1; then
  exec xdg-open "${1:-about:blank}"
else
  echo "No browser found (brave-browser/brave/firefox/xdg-open)."
  exit 1
fi
EOF
  chmod 0755 "$home_dir/.local/bin/browser"
  chown -R "${SUDO_USER:-$USER}":"${SUDO_USER:-$USER}" "$home_dir/.local/bin" 2>/dev/null || true
}

set_default_fish() {
  local target="${SUDO_USER:-$USER}"
  local fish_path
  fish_path="$(command -v fish || true)"
  [[ -n "$fish_path" ]] || { echo "fish not installed; skipping default shell."; return 0; }

  if ! grep -qxF "$fish_path" /etc/shells 2>/dev/null; then
    echo "$fish_path" >> /etc/shells
  fi

  if have_cmd chsh; then
    chsh -s "$fish_path" "$target" || {
      echo "WARNING: chsh failed. Run manually:"
      echo "  chsh -s $fish_path $target"
    }
  else
    echo "WARNING: chsh not found. Install util-linux (or equivalent) then run:"
    echo "  chsh -s $fish_path $target"
  fi
}

ensure_xsession_i3() {
  # Make ~/.xsession that starts i3 so ly can launch it reliably
  local home_dir; home_dir="$(user_home)"
  local target="${SUDO_USER:-$USER}"

  [[ -n "$home_dir" ]] || die "Could not determine user home"
  local xs="$home_dir/.xsession"

  if [[ -e "$xs" ]]; then
    # Don’t overwrite if user already has one.
    return 0
  fi

  cat > "$xs" <<'EOF'
#!/bin/sh
exec i3
EOF
  chmod +x "$xs"
  chown "$target":"$target" "$xs" 2>/dev/null || true
}

enable_ly() {
  # Best-effort enable for systemd (Arch/Debian/Fedora typically) and runit (Void)
  if have_cmd systemctl; then
    # disable common DMs if present (ignore failures)
    systemctl disable --now gdm sddm lightdm lxdm 2>/dev/null || true
    systemctl enable --now ly 2>/dev/null || {
      echo "NOTE: systemctl couldn't enable ly (maybe not installed)."
      return 0
    }
    return 0
  fi

  # Void/runit
  if [[ -d /etc/sv/ly ]]; then
    ln -snf /etc/sv/ly /var/service/ly
  else
    echo "NOTE: /etc/sv/ly not found; cannot enable ly on this system."
  fi
}

deploy_dotfiles() {
  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local src="$repo_root/home"
  [[ -d "$src" ]] || { echo "No ./home directory found; skipping dotfiles deploy."; return 0; }

  local home_dir; home_dir="$(user_home)"
  [[ -n "$home_dir" ]] || die "Could not determine user home"

  echo "Deploying dotfiles from: $src -> $home_dir"
  local ts backup_dir
  ts="$(date +%Y%m%d-%H%M%S)"
  backup_dir="$home_dir/.dotfiles-backup-$ts"
  install -d -m 0755 "$backup_dir"

  while IFS= read -r -d '' item; do
    rel="${item#$src/}"
    dest="$home_dir/$rel"
    dest_dir="$(dirname "$dest")"

    install -d -m 0755 "$dest_dir"

    if [[ -e "$dest" || -L "$dest" ]]; then
      install -d -m 0755 "$backup_dir/$(dirname "$rel")"
      mv -f "$dest" "$backup_dir/$rel"
    fi

    if [[ -d "$item" ]]; then
      install -d -m 0755 "$dest"
    else
      cp -a "$item" "$dest"
    fi
  done < <(find "$src" -mindepth 1 -print0)

  chown -R "${SUDO_USER:-$USER}":"${SUDO_USER:-$USER}" "$home_dir" 2>/dev/null || true
  echo "Backups saved in: $backup_dir"
}

enable_networkmanager_if_possible() {
  if have_cmd systemctl; then
    systemctl enable --now NetworkManager >/dev/null 2>&1 || true
  fi
}

main() {
  need_root "$@"
  ensure_whiptail

  mapfile -t picks < <(choose_components)
  [[ "${#picks[@]}" -gt 0 ]] || { echo "Nothing selected. Exiting."; exit 0; }

  local distro; distro="$(detect_distro)"
  echo "Detected distro: $distro"
  echo "Selected: ${picks[*]}"

  case "$distro" in
    arch|endeavouros|manjaro) install_arch "${picks[@]}" ;;
    debian|ubuntu|linuxmint|pop) install_debian_like "${picks[@]}" ;;
    fedora) install_fedora "${picks[@]}" ;;
    void) install_void "${picks[@]}" ;;
    *) die "Unsupported distro: $distro" ;;
  esac

  selected WRAPPER  "${picks[@]}" && install_browser_wrapper
  selected DOTFILES "${picks[@]}" && deploy_dotfiles

  # Ensure ly can start i3 (and helpful even without ly)
  ensure_xsession_i3

  selected FISH "${picks[@]}" && set_default_fish
  selected LY   "${picks[@]}" && enable_ly

  enable_networkmanager_if_possible

  echo
  echo "Done."
  echo "- If you enabled ly: reboot or switch to tty and check service status if login doesn't show."
  echo "- If you set fish as default shell: log out/in."
  echo "- Your previous configs (if any) were backed up under ~/.dotfiles-backup-<timestamp>."
}

main "$@"
