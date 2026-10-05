# Core defaults shared by all graphical hosts.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  desktop = config.wayland-desktop;
  themes = (import ../themes).themes;
  theme = themes.${desktop.themeName};
  session = {
    command = "uwsm start hyprland-uwsm.desktop";
    user = desktop.autoLoginUser;
  };
in
{
  options = {
    gpu = lib.mkOption {
      type = lib.types.enum [
        "amd"
        "nvidia"
      ];
      description = "GPU driver stack used by this host.";
    };

    wayland-desktop = {
      autoLoginUser = lib.mkOption {
        type = lib.types.str;
        description = "User to auto-login directly into Hyprland.";
      };

      themeName = lib.mkOption {
        type = lib.types.enum (builtins.attrNames themes);
        description = "Theme used by the system-level Stylix configuration.";
      };
    };
  };

  config = lib.mkMerge [
    {
      boot = {
        consoleLogLevel = 0;
        initrd.verbose = false;
        kernelParams = [
          "quiet"
          "loglevel=0"
          "udev.log_level=3"
          "systemd.show_status=true"
        ];
        loader = {
          efi.canTouchEfiVariables = true;
          systemd-boot = {
            enable = true;
            configurationLimit = 20;
          };
        };
      };

      nix = {
        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
        };
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          # Hard-link identical store files to save disk space.
          auto-optimise-store = true;
        };
      };
      nixpkgs.config.allowUnfree = true;

      programs = {
        fish.enable = true;
        hyprland = {
          enable = true;
          withUWSM = true;
        };
        neovim = {
          enable = true;
          defaultEditor = true;
        };
        # Run prebuilt binaries, including editor-installed language servers.
        nix-ld = {
          enable = true;
          # The Microsoft SQL Server extension's bundled .NET services load ICU
          # dynamically and abort at startup when it is absent.
          libraries = [ pkgs.icu ];
        };
      };

      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };

      networking.networkmanager = {
        enable = true;
        dns = "systemd-resolved";
        wifi = {
          backend = "wpa_supplicant";
          powersave = false;
        };
      };

      security = {
        rtkit.enable = true;
        polkit.enablePkexecWrapper = true;
      };

      services = {
        resolved.enable = true;
        samba-wsdd = {
          enable = true;
          openFirewall = true;
        };

        pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
        };

        # Weekly TRIM keeps SSD write performance up.
        fstrim.enable = true;

        gvfs.enable = true;

        # CUPS provides its web UI; Avahi discovers network printers.
        printing.enable = true;
        avahi = {
          enable = true;
          nssmdns4 = true;
          openFirewall = true;
        };

        # Secret service backend for gvfs/nautilus mount credentials.
        gnome.gnome-keyring.enable = true;

        # Launch Hyprland directly and restart it if the session exits.
        greetd = {
          enable = true;
          settings = {
            default_session = session;
            initial_session = session;
          };
        };
      };

      xdg.portal = {
        # Hyprland's module adds GTK automatically, forcing exact backends for the terminal file picker.
        extraPortals = lib.mkForce (
          with pkgs;
          [
            xdg-desktop-portal-hyprland
            xdg-desktop-portal-termfilechooser
            # GTK4 needs the Settings portal for live appearance changes on Wayland.
            xdg-desktop-portal-gtk
          ]
        );
        config.hyprland = {
          default = [ "hyprland" ];
          "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
          # The GTK backend stays pinned to this interface so it cannot take over the file picker.
          "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
        };
      };

      stylix = {
        enable = true;
        polarity = theme.polarity;
        base16Scheme = theme.colors;
        image = theme.wallpaper;

        # Keep boot and virtual consoles on their default palette.
        targets = {
          console.enable = false;
          fish.enable = false;
        };

        cursor = {
          package = pkgs.adwaita-icon-theme;
          name = "Adwaita";
          size = 24;
        };

        fonts = {
          sizes = {
            applications = 11;
            terminal = 11.5;
            desktop = 11;
            popups = 11;
          };

          serif = {
            package = pkgs.source-serif-pro;
            name = "Source Serif Pro";
          };

          sansSerif = {
            package = pkgs.inter;
            name = "Inter";
          };

          monospace = {
            package = pkgs.nerd-fonts.jetbrains-mono;
            name = "JetBrainsMono Nerd Font";
          };

          emoji = {
            package = pkgs.noto-fonts-color-emoji;
            name = "Noto Color Emoji";
          };
        };
      };
    }

    (lib.mkIf (config.gpu == "amd") {
      services.xserver.videoDrivers = [ "amdgpu" ];
    })

    (lib.mkIf (config.gpu == "nvidia") {
      services.xserver.videoDrivers = [ "nvidia" ];

      # Loading NVIDIA KMS in initrd avoids a black screen before greetd grabs the GPU.
      boot.initrd.kernelModules = [ "nvidia" ];

      systemd.services = {
        # logind emits PrepareForSleep(false) when the sleep target completes.
        nvidia-resume = {
          before = [
            "suspend.target"
            "hibernate.target"
            "suspend-then-hibernate.target"
          ];
          after = [ "systemd-suspend-then-hibernate.service" ];
          requiredBy = [ "systemd-suspend-then-hibernate.service" ];
        };
        nvidia-suspend = {
          before = [ "systemd-suspend-then-hibernate.service" ];
          requiredBy = [ "systemd-suspend-then-hibernate.service" ];
        };
      };

      # NVIDIA's hook handles the internal suspend -> hibernate transition.
      environment.etc."systemd/system-sleep/nvidia".source =
        pkgs.writeShellScript "nvidia-combined-sleep" ''
          if [ "$2" = suspend-then-hibernate ]; then
            exec ${config.hardware.nvidia.package}/lib/systemd/system-sleep/nvidia "$@"
          fi
        '';

      hardware.nvidia = {
        modesetting.enable = true;
        nvidiaSettings = true;
        open = false;
        package = config.boot.kernelPackages.nvidiaPackages.stable;
        powerManagement.enable = true;
        moduleParams.nvidia.NVreg_TemporaryFilePath = "/var/tmp";
      };
    })
  ];
}
