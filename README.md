# Yoga Slim 7x NixOS Rice

Sanitized NixOS flake template for a Lenovo Yoga Slim 7x Snapdragon machine using KDE Plasma 6, Home Manager, Plasma Manager, Helium, Ghostty, Vesktop, Kate, and a custom Wayland overlay inspired by a translucent desktop rice.

This repository intentionally omits private machine data:

- no real username or hostname
- no passwords or password hashes
- no disk UUIDs
- no Tailscale machine identity or state
- no private wallpaper asset

## What It Configures

- Lenovo Yoga Slim 7x / X1E hardware module
- Plasma 6 with `plasma-login-manager`
- UK international keyboard layout
- Europe/Madrid timezone and US English locale
- PipeWire audio
- Bluetooth available but not powered on at boot
- Tailscale enabled and ordered after NetworkManager online
- KDE Wallet disabled
- Helium as default browser
- Kate and Nano as visual/terminal editors
- A fullscreen PySide6 Wayland rice overlay:
  - wallpaper-backed glass panels
  - real battery percentage
  - clickable top-left app/menu actions
  - real installed `.desktop` app search
  - favorite app list when search is empty
  - centered translucent dock with hover tooltip support

## Use

1. Install NixOS on the target machine.
2. Replace the placeholder user and host in `flake.nix`:

   ```nix
   username = "your-user";
   hostname = "your-host";
   ```

3. Generate target hardware config:

   ```bash
   sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
   ```

4. Copy this repo to `/etc/nixos` or adjust the path.
5. Build:

   ```bash
   sudo nixos-rebuild switch --flake .#yoga-slim-7x
   ```

6. Set a password for the user if needed:

   ```bash
   sudo passwd your-user
   ```

## Wallpaper

The committed `assets/wallpaper.svg` is only a placeholder. Replace it with your own image and update `home.nix` if you change the filename.

## Notes

The overlay is a pragmatic rice layer, not a general desktop environment. It assumes a KDE Wayland session and uses Qt/PySide6 directly so the layout can be managed declaratively from Home Manager.
