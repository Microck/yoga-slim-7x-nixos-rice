{
  config,
  hostname,
  inputs,
  pkgs,
  username,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
  ];

  hardware.lenovo-yoga-slim7x.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = hostname;
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Madrid";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "uk";

  nixpkgs.config.allowUnfree = true;
  programs.zsh.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    description = "NixOS user";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    shell = pkgs.zsh;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = false;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "gb";
    variant = "intl";
  };

  services.displayManager.sddm.enable = false;
  services.displayManager.plasma-login-manager.enable = true;
  services.desktopManager.plasma6.enable = true;

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
    IdleAction = "ignore";
    IdleActionSec = "0";
  };

  services.tailscale.enable = true;
  systemd.services.NetworkManager-wait-online.enable = true;
  systemd.services.tailscaled = {
    wants = [ "NetworkManager-wait-online.service" ];
    after = [ "NetworkManager-wait-online.service" ];
    wantedBy = [ "multi-user.target" ];
  };

  xdg.mime.defaultApplications = {
    "text/html" = "helium.desktop";
    "x-scheme-handler/http" = "helium.desktop";
    "x-scheme-handler/https" = "helium.desktop";
  };

  environment.etc."xdg/kwalletrc".text = ''
    [Wallet]
    Enabled=false
  '';

  environment.systemPackages = with pkgs; [
    inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.home-manager
    codex
    curl
    ghostty
    git
    kdePackages.kate
    nano
    vesktop
    vim
    wget
  ];

  fonts.packages = with pkgs; [
    inter
    jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
    papirus-icon-theme
  ];

  environment.variables = {
    BROWSER = "helium";
    EDITOR = "nano";
    VISUAL = "kate";
  };

  system.stateVersion = "25.05";
}
