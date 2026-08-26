{ config, ... }:

let
  colors = config.lib.stylix.colors.withHashtag;
in
{
  # custom theme.toml below renders semantic colors directly
  stylix.targets.yazi.enable = false;

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
    };
  };

  xdg = {
    configFile."yazi/theme.toml".text = ''
      [mgr]
      cwd             = { fg = "${colors.base0D}" }
      find_keyword    = { fg = "${colors.base0A}", bold = true, underline = true }
      find_position   = { fg = "${colors.base05}", bg = "reset", bold = true }
      marker_copied   = { fg = "${colors.base0B}",  bg = "${colors.base0B}" }
      marker_cut      = { fg = "${colors.base08}",    bg = "${colors.base08}" }
      marker_marked   = { fg = "${colors.base0C}",   bg = "${colors.base0C}" }
      marker_selected = { fg = "${colors.base0A}", bg = "${colors.base0A}" }
      count_copied    = { bg = "${colors.base0B}" }
      count_cut       = { bg = "${colors.base08}" }
      count_selected  = { bg = "${colors.base0A}" }
      border_symbol   = "│"
      border_style    = { fg = "${colors.base03}" }

      [indicator]
      parent  = { fg = "${colors.base04}", bg = "${colors.base01}" }
      current = { fg = "${colors.base07}", bg = "${colors.base03}", bold = true }
      preview = { fg = "${colors.base04}", bg = "${colors.base01}" }
      padding = { open = "▐", close = "▌" }

      [tabs]
      active    = { fg = "${colors.base02}", bg = "${colors.base0D}", bold = true }
      inactive  = { fg = "${colors.base0D}", bg = "${colors.base02}" }
      sep_inner = { open = " ", close = " " }
      sep_outer = { open = " ", close = " " }

      [mode]
      normal_main = { fg = "${colors.base01}", bg = "${colors.base0D}", bold = true }
      normal_alt  = { fg = "${colors.base0D}", bg = "${colors.base02}" }
      # Matches marker_selected below so visual-select mode and the files it
      # marks read as the same action instead of two unrelated accents.
      select_main = { fg = "${colors.base01}", bg = "${colors.base0A}", bold = true }
      select_alt  = { fg = "${colors.base0A}", bg = "${colors.base02}" }
      unset_main  = { fg = "${colors.base07}", bg = "${colors.base04}", bold = true }
      unset_alt   = { fg = "${colors.base04}", bg = "${colors.base02}" }

      [status]
      sep_left  = { open = " ", close = " " }
      sep_right = { open = " ", close = " " }
      perm_sep        = { fg = "${colors.base03}" }
      perm_type       = { fg = "${colors.base0D}" }
      perm_read       = { fg = "${colors.base0A}" }
      perm_write      = { fg = "${colors.base08}" }
      perm_exec       = { fg = "${colors.base0B}" }
      progress_label  = { fg = "${colors.base05}", bold = true }
      progress_normal = { fg = "${colors.base0B}", bg = "${colors.base02}" }
      progress_error  = { fg = "${colors.base0A}", bg = "${colors.base08}" }

      [confirm]
      border  = { fg = "${colors.base0D}" }
      title   = { fg = "${colors.base0D}", bold = true }
      body    = { fg = "${colors.base05}" }
      list    = { fg = "${colors.base05}" }
      btn_yes = { fg = "${colors.base02}", bg = "${colors.base0D}", bold = true }
      btn_no  = { fg = "${colors.base05}", bg = "${colors.base02}" }

      [pick]
      border   = { fg = "${colors.base0D}" }
      active   = { fg = "${colors.base05}", bold = true }
      inactive = { fg = "${colors.base05}" }

      [input]
      border   = { fg = "${colors.base0D}" }
      title    = { fg = "${colors.base0D}" }
      value    = { fg = "${colors.base05}" }
      selected = { reversed = true }

      [cmp]
      border   = { fg = "${colors.base0D}" }
      active   = { fg = "${colors.base02}", bg = "${colors.base0D}" }
      inactive = { fg = "${colors.base05}" }

      [tasks]
      border  = { fg = "${colors.base0D}" }
      title   = { fg = "${colors.base0D}" }
      hovered = { fg = "${colors.base05}", bold = true }

      [which]
      mask            = { bg = "${colors.base02}" }
      rest            = { fg = "${colors.base03}" }
      desc            = { fg = "${colors.base05}" }
      separator       = "  "
      separator_style = { fg = "${colors.base03}" }

      [help]
      on      = { fg = "${colors.base0C}" }
      run     = { fg = "${colors.base05}" }
      hovered = { reversed = true, bold = true }
      footer  = { fg = "${colors.base01}", bg = "${colors.base0D}" }

      [spot]
      border   = { fg = "${colors.base0D}" }
      title    = { fg = "${colors.base0D}" }
      tbl_cell = { fg = "${colors.base05}", bg = "${colors.base02}" }

      [icon]
      dirs = []
      prepend_conds = [
        { if = "dir & hovered", text = "󰝰", fg = "${colors.base0D}" },
        { if = "dir",           text = "󰉋", fg = "${colors.base0D}" },
      ]

      [filetype]
      # Colors mirror the box/gradient roles Stylix already assigns btop
      # (cpu = magenta, mem = green, net/cyan = media, temp/yellow = warning,
      # blue = primary), so file categories read the same across TUIs
      # instead of collapsing into one flat foreground color.
      rules = [
        { url = "*", is = "hidden", fg = "${colors.base03}" },
        { url = "*/", is = "hidden", fg = "${colors.base03}" },
        { mime = "image/*", fg = "${colors.base0E}" },
        { mime = "video/*", fg = "${colors.base0E}" },
        { mime = "audio/*", fg = "${colors.base0C}" },
        { mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}", fg = "${colors.base0A}" },
        { mime = "application/{pdf,doc,rtf}", fg = "${colors.base0D}" },
        { mime = "vfs/{absent,stale}", fg = "${colors.base04}" },
        { url = "*/", fg = "${colors.base0D}" },
        { url = "*", fg = "${colors.base05}" },
      ]
    '';
  };
}
