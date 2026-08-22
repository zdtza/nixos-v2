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
  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      stylix,
      ...
    }:
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        modules = [
          # main config
          ./configuration.nix

          # extra flakes
          stylix.nixosModules.stylix
          home-manager.nixosModules.home-manager

          # home manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs self; };

            home-manager.users.zdtza = {
              imports = [
                ./home-manager/repo.nix
                ./home-manager/defaults.nix
                ./home-manager/appearance.nix
                ./home-manager/kitty.nix
                ./home-manager/shell.nix
                ./home-manager/hyprland.nix
                ./home-manager/hypridle.nix
                ./home-manager/hyprsunset.nix
                ./home-manager/pi.nix
                ./home-manager/screen-share.nix
                ./home-manager/voxtype.nix
                ./home-manager/btop.nix
                ./home-manager/nvim.nix
                ./home-manager/git.nix
                ./home-manager/web-apps.nix
                ./home-manager/fzf.nix
                ./home-manager/yazi.nix
                ./home-manager/npm.nix
                ./home-manager/quickshell.nix
              ];
              home.stateVersion = "26.05";
            };
          }
        ];
      };
    };
}
