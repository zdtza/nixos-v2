{ ... }:

{
  flake.nixosModules.core =
    { pkgs, ... }:
    {
      networking.hostName = "legion";
      networking.networkmanager.enable = true;
      networking.firewall.enable = false;

      time.timeZone = "Africa/Johannesburg";
      i18n.defaultLocale = "en_ZA.UTF-8";

      services.xserver.xkb = {
        layout = "za";
        variant = "";
      };

      # Don't forget to set a password with `passwd`.
      users.users."cdt" = {
        isNormalUser = true;
        description = "Connor du Toit";
        extraGroups = [ "networkmanager" "wheel" ];
        packages = with pkgs; [ ];
      };

      nixpkgs.config.allowUnfree = true;

      environment.systemPackages = with pkgs; [
        neovim
        kitty
        eza
        fzf
        zoxide
        yazi
        nautilus
        # hyprland.lua keybindings/settings dependencies
        hyprpicker
        grim
        slurp
        wl-clipboard
        brightnessctl
      ];

      system.stateVersion = "26.05";
    };
}
