{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    impermanence.url = "github:nix-community/impermanence";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, disko, ... }: {
    nixosConfigurations.legion = nixpkgs.lib.nixosSystem {
      modules = [
      	inputs.impermanence.nixosModules.impermanence
      	home-manager.nixosModules.home-manager
      	disko.nixosModules.disko
      	./configuration.nix
	      ./impermanence.nix
	      ./disko.nix
      ];
    };
  };
}

