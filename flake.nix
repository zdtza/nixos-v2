{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland-preview-share-picker = {
      url = "git+https://github.com/WhySoBad/hyprland-preview-share-picker?submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs@{ self, nixpkgs, home-manager, stylix, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      modules = [
	      ./configuration.nix

        stylix.nixosModules.stylix
        home-manager.nixosModules.home-manager

        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit inputs; };

          home-manager.users.cdt = {
            imports = [
              ./home/defaults.nix
              ./home/kitty.nix
              ./home/shell.nix
              ./home/hyprland.nix
              ./home/pi.nix
              ./home/screen-share.nix
              ./home/voxtype.nix
              ./home/btop.nix
              ./home/nvim.nix
              ./home/git.nix
              ./home/apps.nix
              ./home/fzf.nix
              ./home/yazi.nix
              ./home/npm.nix
            ];
            home.stateVersion = "26.05";
          };
        }
      ];
    };
  };
}

