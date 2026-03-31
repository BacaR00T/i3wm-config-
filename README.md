# dotfiles

My dotfiles managed with GNU Stow.

## packages

- i3
- alacritty
- fish
- extras

## clone

```bash
git clone https://github.com/BacaR00T/i3wm-config- ~/dotfiles/i3wm-config-
cd ~/dotfiles/i3wm-config-
yay -S alacritty dmenu input-remapper polkit-gnome brave-bin thunar feh picom fish

stow
stow -t ~ alacritty fish i3 extras

unstow
stow -t ~ -D alacritty fish i3 extras

restow
stow -t ~ -R alacritty fish i3 extras
```

![literally me](lain.png)
