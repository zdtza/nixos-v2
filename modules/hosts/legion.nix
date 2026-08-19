{ inputs, self, ... }:

{
  flake.nixosConfigurations.legion = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      inputs.impermanence.nixosModules.impermanence
      inputs.home-manager.nixosModules.home-manager
      inputs.disko.nixosModules.disko
      inputs.stylix.nixosModules.stylix

      self.nixosModules.boot
      self.nixosModules.core
      self.nixosModules.hardware
      self.nixosModules.hyprland
      self.nixosModules.impermanence
      self.nixosModules.disk
      self.nixosModules.theme

      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users."cdt" = {
          imports = [
            self.homeModules.hyprland
            self.homeModules.shell
          ];
          home.stateVersion = "26.05";
        };
      }
    ];
  };
}
