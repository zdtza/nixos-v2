{ pkgs, ... }:

let
  # Prints the cwd of the active window's terminal so a new terminal can be
  # opened in the same scope. Prefers kitty's remote-control socket (exact
  # cwd of the focused tab); falls back to walking /proc for non-kitty
  # shells, validated against /etc/shells so cwd isn't guessed from an
  # arbitrary child process.
  terminalCwd = pkgs.writeShellScriptBin "terminal-cwd" ''
    #!/usr/bin/env bash
    set -uo pipefail

    terminal_pid=$(hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.pid')
    kitty_socket="$XDG_RUNTIME_DIR/kitty-$terminal_pid"
    cwd=""

    if [[ -S $kitty_socket ]]; then
      cwd=$(${pkgs.kitty}/bin/kitten @ --to "unix:$kitty_socket" ls --match "state:focused" 2>/dev/null |
        ${pkgs.jq}/bin/jq -r '.[].tabs[].windows[].cwd // empty')
    else
      shell_pid=$(${pkgs.procps}/bin/pgrep -P "$terminal_pid" | tail -n1)

      if [[ -n $shell_pid ]]; then
        cwd=$(readlink -f "/proc/$shell_pid/cwd" 2>/dev/null)
        shell=$(readlink -f "/proc/$shell_pid/exe" 2>/dev/null)
        grep -Fqsx "$shell" /etc/shells || cwd=""
      fi
    fi

    if [[ -d $cwd ]]; then
      echo "$cwd"
    else
      echo "$HOME"
    fi
  '';

  # Launches a new terminal in the same cwd as the focused one.
  launchTerminal = pkgs.writeShellScriptBin "launch-terminal-cwd" ''
    #!/usr/bin/env bash
    exec ${pkgs.kitty}/bin/kitty --directory "$(${terminalCwd}/bin/terminal-cwd)" "$@"
  '';
in
{
  home.packages = [ terminalCwd launchTerminal ];

  programs.kitty = {
    enable = true;
    settings = {
      window_padding_width = 6;
      confirm_os_window_close = 0;
      enable_audio_bell = false;

      cursor_trail = 50;
      cursor_trail_decay = "0.08 0.25";
      cursor_trail_start_threshold = 2;

      # Per-instance remote-control socket, named by kitty's own pid, so
      # terminal-cwd can query the exact focused tab's cwd instead of
      # guessing from /proc.
      allow_remote_control = true;
      listen_on = "unix:\${XDG_RUNTIME_DIR}/kitty-{kitty_pid}";
    };

    keybindings = {
      "ctrl+insert" = "copy_to_clipboard";
      "shift+insert" = "paste_from_clipboard";
      "shift+delete" = "copy_to_clipboard";
    };
  };
}
