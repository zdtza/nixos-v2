{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  picker = inputs.hyprland-preview-share-picker.packages.${pkgs.stdenv.hostPlatform.system}.default;
  colors = config.lib.stylix.colors.withHashtag;
  font = config.stylix.fonts.monospace.name;

  yamlFormat = pkgs.formats.yaml { };
in
{
  home.packages = [
    picker
    pkgs.slurp
  ];

  # enabling the custom screen share picker for hyprland
  xdg.configFile."hypr/xdph.conf".text = ''
    screencopy {
      custom_picker_binary = ${lib.getExe' picker "hyprland-preview-share-picker"}
      allow_token_by_default = 1
    }
  '';

  # yaml config for the screen picker
  xdg.configFile."hyprland-preview-share-picker/config.yaml".source = yamlFormat.generate "screensharepicker-config.yaml" {
    stylesheets = [ "style.css" ];
    default_page = "outputs";

    window = {
      height = 500;
      width = 1000;
    };

    image = {
      resize_size = 500;
      widget_size = 150;
    };

    classes = {
      window = "window";
      image_card = "card";
      image_card_loading = "card-loading";
      image = "image";
      image_label = "image-label";
      notebook = "notebook";
      tab_label = "tab-label";
      notebook_page = "page";
      region_button = "region-button";
      restore_button = "restore-button";
    };

    windows = {
      min_per_row = 3;
      max_per_row = 999;
      clicks = 1;
      spacing = 12;
    };

    outputs = {
      clicks = 1;
      spacing = 6;
      show_label = false;
      respect_output_scaling = true;
    };

    region.command = "slurp -f '%o@%x,%y,%w,%h'";

    hide_token_restore = true;
    debug = false;
  };

  # styling the screen share picker to match the rest of the system
  xdg.configFile."hyprland-preview-share-picker/style.css".text = ''
    @define-color foreground ${colors.base05};
    @define-color background ${colors.base00};
    @define-color accent ${colors.base0D};
    @define-color muted ${colors.base03};
    @define-color card_bg ${colors.base02};
    @define-color text_dark ${colors.base00};
    @define-color accent_hover ${colors.base07};
    @define-color selected_tab ${colors.base0D};
    @define-color text ${colors.base05};

    * {
      all: unset;
      font-family: "${font}";
      color: @foreground;
      font-weight: bold;
      font-size: 16px;
    }

    .window {
      background: alpha(@background, 0.95);
      border: solid 2px @accent;
      margin: 4px;
      padding: 18px;
    }

    tabs {
      padding: 0.5rem 1rem;
    }

    tabs > tab {
      margin-right: 1rem;
    }

    .tab-label {
      color: @text;
      transition: all 0.2s ease;
    }

    tabs > tab:checked > .tab-label,
    tabs > tab:active > .tab-label {
      text-decoration: underline currentColor;
      color: @selected_tab;
    }

    tabs > tab:focus > .tab-label {
      color: @foreground;
    }

    .page {
      padding: 1rem;
    }

    .image-label {
      font-size: 12px;
      padding: 0.25rem;
    }

    flowboxchild > .card,
    button > .card {
      transition: all 0.2s ease;
      border: solid 2px transparent;
      border-color: @background;
      border-radius: 5px;
      background-color: @card_bg;
      padding: 5px;
    }

    flowboxchild:hover > .card,
    button:hover > .card,
    flowboxchild:active > .card,
    flowboxchild:selected > .card,
    button:active > .card,
    button:selected > .card,
    button:focus > .card {
      border: solid 2px @accent;
    }

    .image {
      border-radius: 5px;
    }

    .region-button {
      padding: 0.5rem 1rem;
      border-radius: 5px;
      background-color: @accent;
      color: @text_dark;
      transition: all 0.2s ease;
    }

    .region-button > label {
      color: @text_dark;
    }

    .region-button:not(:disabled):hover,
    .region-button:not(:disabled):focus {
      background-color: @accent_hover;
      color: @text_dark;
    }

    .region-button:disabled {
      background-color: @muted;
      color: @background;
    }
  '';
}
