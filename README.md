# dotfiles

My dotfiles managed with GNU Stow.

## packages

- i3
- alacritty
- fish
- extras

## clone

```bash
git clone https://github.com/BacaR00T/dotfiles
cd ~/dotfiles/
yay -S alacritty dmenu input-remapper polkit-gnome brave-bin thunar feh picom fish stow i3status-rust

stow
stow -t ~ alacritty fish i3 i3status-rust extras

unstow
stow -t ~ -D alacritty fish i3 i3status-rust extras

restow
stow -t ~ -R alacritty fish i3 i3status-rust extras
```

![literally me](lain.png)
