{ config, pkgs, ... }:

let
  colors = config.lib.stylix.colors.withHashtag;
in
{
  # custom theme.toml below renders semantic colors directly
  stylix.targets.yazi.enable = false;

  home.packages = [
    pkgs.imv
    pkgs.mpv
  ];

  programs.yazi = {
    enable = true;
    settings = {
      mgr = {
        ratio = [
          2
          4
          3
        ];
        show_hidden = false;
      };

      opener = {
        edit = [
          {
            run = "nvim %*";
            block = true;
            desc = "Neovim";
          }
        ];
        view = [
          {
            run = "uwsm app -- imv %*";
            block = false;
            desc = "imv";
          }
          {
            run = "xdg-open %*";
            block = false;
            desc = "Open";
          }
        ];
        play = [
          {
            run = "uwsm app -- mpv %*";
            block = false;
            desc = "mpv";
          }
        ];
        open = [
          {
            run = "xdg-open %*";
            block = false;
            desc = "Open";
          }
        ];
      };

      open.rules = [
        {
          mime = "inode/x-empty";
          use = [ "edit" ];
        }
        {
          mime = "text/*";
          use = [ "edit" ];
        }
        {
          mime = "application/{json,ld+json,javascript,typescript,x-yaml,toml,xml,x-sh,x-shellscript}";
          use = [ "edit" ];
        }
        {
          url = "*.{md,markdown,txt,log,csv,tsv,json,jsonc,yml,yaml,toml,xml,html,css,js,jsx,ts,tsx,py,sh,bash,zsh,lua,nix,rs,go,c,cpp,h,hpp}";
          use = [ "edit" ];
        }
        {
          mime = "image/*";
          use = [
            "view"
            "edit"
          ];
        }
        {
          mime = "{audio,video}/*";
          use = [ "play" ];
        }
        {
          mime = "*";
          use = [ "open" ];
        }
      ];
    };
  };

  xdg = {
    configFile."yazi/theme.toml".source = pkgs.replaceVars ../templates/yazi/theme.toml {
      accent = colors.base0D;
      bright_foreground = colors.base07;
      cyan = colors.base0C;
      foreground = colors.base05;
      green = colors.base0B;
      muted = colors.base03;
      red = colors.base08;
      selection = colors.base02;
      yellow = colors.base0A;
    };
  };
}
