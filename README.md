# i3 + X11 Dotfiles

Dotfiles + a bootstrap script for setting up a fresh Linux install with **X11 + i3**.

> Install a clean system → clone this repo → run one script → get your environment back.

---

## What you get

- **i3 (X11)** setup
- **Alacritty** config
- Optional: **picom**, **i3status**, **fish**, **Brave**
- Optional: **ly** display manager enable (best-effort across distros)
- A simple **TUI installer** (checklist menu)
- Dotfiles deployment by **copying** files from `./home` into your `$HOME` (with backups)

---

## Repo layout

Everything under `home/` mirrors your real home directory:

```

home/
.config/i3/config
.config/alacritty/alacritty.toml
.config/picom/picom.conf
.config/i3status/config
.config/fish/config.fish
.local/bin/browser

````

The bootstrap script copies these to `~` on install.

---

## Supported distros

Best-effort support for:

- Arch / EndeavourOS / Manjaro
- Debian / Ubuntu / Mint / Pop!_OS
- Fedora
- Void

Some packages aren’t equally available everywhere (notably **ly** and sometimes **Brave** on Void). The script will tell you when it has to skip something.

---

## Quick start (fresh machine)

Install `git`, clone, run:

```bash
# install git (pick your distro)
sudo pacman -S git            # Arch
sudo apt install git          # Debian/Ubuntu
sudo dnf install git          # Fedora
sudo xbps-install -S git      # Void

git clone https://github.com/BacaR00T/i3wm-config- dotfiles
cd dotfiles
chmod +x bootstrap.sh
./bootstrap.sh
````

You’ll get a checklist menu where you can select what to install/setup.

---

## What the script does

Depending on your selection, it can:

* Install i3 essentials (i3status / i3lock / xss-lock / dex / nm-applet / polkit / picom / feh)
* Install basic apps (alacritty / dmenu / thunar)
* Install **fish** and set it as your **default login shell**
* Install + enable **ly** display manager (best-effort)
* Deploy dotfiles from `./home` into your `$HOME`

  * Existing files are backed up to: `~/.dotfiles-backup-<timestamp>/`
* Create `~/.xsession` (if missing) so **ly** can start i3 reliably

---

## Updating configs

Edit files inside `home/`, then:

```bash
git add home
git commit -m "Update configs"
git push
```

On another machine:

```bash
cd ~/dotfiles
git pull
./bootstrap.sh
```

---

## Safety

Don’t commit secrets (tokens, browser profiles, keyrings, etc.). Deployment makes backups in `~/.dotfiles-backup-<timestamp>/`.

---

## License

Personal dotfiles. Use at your own risk.
