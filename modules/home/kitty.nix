{ ... }:

{
  flake.homeModules.kitty =
    { config, pkgs, ... }:
    {
      programs.kitty = {
        enable = true;

        settings = {
          font_size = 13;
          window_padding_width = 6;
          confirm_os_window_close = 0;
          enable_audio_bell = false;
          
          cursor_trail = 50;
          cursor_trail_decay = "0.08 0.25";
          cursor_trail_start_threshold = 2;
        };

        keybindings = {
          "ctrl+insert" = "copy_to_clipboard";
          "shift+insert" = "paste_from_clipboard";
          "shift+delete" = "copy_to_clipboard";
          "ctrl+shift+f12" = "new_os_window_with_cwd";
        };
      };
    };
}
