{ pkgs, ... }:

let
  # printing the focused kitty window's cwd via its remote-control socket
  terminalCwd = pkgs.writeShellScriptBin "terminal-cwd" ''
    #!/usr/bin/env bash
    set -uo pipefail

    terminal_pid=$(hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.pid')
    cwd=$(${pkgs.kitty}/bin/kitten @ --to "unix:$XDG_RUNTIME_DIR/kitty-$terminal_pid" ls --match "state:focused" 2>/dev/null |
      ${pkgs.jq}/bin/jq -r '.[].tabs[].windows[].cwd // empty')

    if [[ -d $cwd ]]; then
      echo "$cwd"
    else
      echo "$HOME"
    fi
  '';

  # launching a new terminal in the same cwd as the focused one
  launchTerminal = pkgs.writeShellScriptBin "launch-terminal-cwd" ''
    #!/usr/bin/env bash
    exec ${pkgs.kitty}/bin/kitty --directory "$(${terminalCwd}/bin/terminal-cwd)" "$@"
  '';
in
{
  home.packages = [
    terminalCwd
    launchTerminal
  ];

  programs.kitty = {
    enable = true;
    settings = {
      window_padding_width = 6;
      confirm_os_window_close = 0;
      enable_audio_bell = false;

      cursor_trail = 50;
      cursor_trail_decay = "0.08 0.25";
      cursor_trail_start_threshold = 2;

      # per-instance remote-control socket, lets terminal-cwd query the exact focused tab
      allow_remote_control = true;
      listen_on = "unix:\${XDG_RUNTIME_DIR}/kitty-{kitty_pid}";
    };

    # universal copy / paste keybindings
    keybindings = {
      "ctrl+insert" = "copy_to_clipboard";
      "shift+insert" = "paste_from_clipboard";
      "shift+delete" = "copy_to_clipboard";
    };
  };
}
