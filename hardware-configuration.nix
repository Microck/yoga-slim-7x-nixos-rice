{
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "nvme" ];
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  # Generate this file on the target machine with:
  #
  #   sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
  #
  # Disk UUIDs and partition layout are machine-specific, so this template does
  # not publish a real host's generated file.
}
