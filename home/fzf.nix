{ ... }:

{
  # Disable Stylix so it doesn't overwrite the ANSI mapping below
  stylix.targets.fzf.enable = false;

  programs.fzf = {
    enable = true;
    defaultOptions = [
      # === COMPLETE ANSI TERMINAL COLOR REFERENCE ===
      # -1 : Default Terminal Background/Foreground
      #  0 : Black        |  8 : Bright Black / Dark Grey (Selection bar)
      #  1 : Red          |  9 : Bright Red
      #  2 : Green (Icon) | 10 : Bright Green
      #  3 : Yellow (Match/Select)| 11 : Bright Yellow
      #  4 : Blue (Pointer)| 12 : Bright Blue
      #  5 : Magenta (Info)| 13 : Bright Magenta
      #  6 : Cyan (Header/Spinner)| 14 : Bright Cyan
      #  7 : White (Text) | 15 : Bright White (Selected text)
      
      "--color=bg:-1,fg:-1,bg+:8,fg+:15,hl:6,hl+:6,pointer:6,marker:6,info:6,prompt:6,spinner:6,header:6"
    ];
  };
}
