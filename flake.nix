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
      # Reusable pieces, importable by this flake's own host below or by any
      # other flake that takes this repo as an input. Add a `nixosModules.<x>`
      # / `homeManagerModules.<x>` pair here as more of the config is split
      # out this way.
      nixosModules.windows = ./modules/windows/nixos.nix;
      homeManagerModules.windows = ./modules/windows/home.nix;

      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        modules = [
          # main config
          ./configuration.nix
          self.nixosModules.windows

          # external modules
          stylix.nixosModules.stylix
          home-manager.nixosModules.home-manager

          # home manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs self; };
            home-manager.sharedModules = [ self.homeManagerModules.windows ];

            home-manager.users.zdtza = {
              imports = [
                ./home/repo.nix
                ./home/defaults.nix
                ./home/appearance.nix
                ./home/kitty.nix
                ./home/shell.nix
                ./home/hyprland.nix
                ./home/hypridle.nix
                ./home/hyprsunset.nix
                ./home/pi.nix
                ./home/screen-share.nix
                ./home/voxtype.nix
                ./home/btop.nix
                ./home/nvim.nix
                ./home/git.nix
                ./home/web-apps.nix
                ./home/fzf.nix
                ./home/polkit-agent.nix
                ./home/yazi.nix
                ./home/npm.nix
                ./home/quickshell.nix
                ./home/lazydocker.nix
              ];
              home.stateVersion = "26.05";
            };
          }
        ];
      };
    };
}
