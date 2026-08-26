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
    let
      # One user across every host this repo manages. Parametrize this too
      # if that ever stops being true.
      user = "zdtza";
      homeStateVersion = "26.05";

      # Every host's default.nix imports whichever ./modules/*.nix files it
      # needs directly and sets its own home-manager.users.<user>.imports.
      # Add a new machine by dropping a directory in ./hosts and its name
      # in here.
      hostNames = [ "legion" ];

      mkHost =
        hostname:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            # import current host configuration
            ./hosts/${hostname}

            # external modules
            stylix.nixosModules.stylix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs self; };
              home-manager.users.${user}.home.stateVersion = homeStateVersion;
            }
          ];
        };
    in
    {
      nixosConfigurations = nixpkgs.lib.genAttrs hostNames mkHost;
    };
}
