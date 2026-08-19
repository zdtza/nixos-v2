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

      # Declarative so login works right after install with no manual
      # passwd step. Change it after first login with `passwd`.
      users.users."cdt" = {
        isNormalUser = true;
        description = "Connor du Toit";
        extraGroups = [ "networkmanager" "wheel" ];
        packages = with pkgs; [ ];
        initialPassword = "changeme";
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
        claude-code
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
