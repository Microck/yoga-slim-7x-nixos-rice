{
  description = "NixOS configuration template for a Lenovo Yoga Slim 7x Snapdragon KDE rice";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    x1e-nixos-config.url = "github:kuruczgy/x1e-nixos-config";
    x1e-nixos-config.inputs.nixpkgs.follows = "nixpkgs";

    helium.url = "github:schembriaiden/helium-browser-nix-flake";
    helium.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    plasma-manager.url = "github:nix-community/plasma-manager";
    plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.inputs.home-manager.follows = "home-manager";

    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs =
    inputs@{
      nixpkgs,
      x1e-nixos-config,
      home-manager,
      plasma-manager,
      sops-nix,
      ...
    }:
    let
      system = "aarch64-linux";
      username = "nixos-user";
      hostname = "yoga-slim-7x";
    in
    {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs username hostname;
        };
        modules = [
          x1e-nixos-config.nixosModules.x1e
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.extraSpecialArgs = {
              inherit inputs username;
            };
            home-manager.sharedModules = [
              plasma-manager.homeModules.plasma-manager
            ];
            home-manager.users.${username} = import ./home.nix;
          }
          ./configuration.nix
        ];
      };
    };
}
