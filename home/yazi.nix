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
      find_position   = { fg = "${colors.base09}", bg = "reset", bold = true }
      marker_copied   = { fg = "${colors.base0B}",  bg = "${colors.base0B}" }
      marker_cut      = { fg = "${colors.base08}",    bg = "${colors.base08}" }
      marker_marked   = { fg = "${colors.base0C}",   bg = "${colors.base0C}" }
      marker_selected = { fg = "${colors.base0A}", bg = "${colors.base0A}" }
      count_copied    = { bg = "${colors.base0B}" }
      count_cut       = { bg = "${colors.base08}" }
      count_selected  = { bg = "${colors.base0A}" }
      border_symbol   = "│"
      border_style    = { fg = "${colors.base0E}" }

      [indicator]
      parent  = { fg = "${colors.base07}", bg = "${colors.base02}" }
      current = { fg = "${colors.base07}", bg = "${colors.base02}", bold = true }
      preview = { fg = "${colors.base07}", bg = "${colors.base02}" }
      padding = { open = "▐", close = "▌" }

      [tabs]
      active    = { fg = "${colors.base02}", bg = "${colors.base0E}", bold = true }
      inactive  = { fg = "${colors.base0E}", bg = "${colors.base02}" }
      sep_inner = { open = " ", close = " " }
      sep_outer = { open = " ", close = " " }

      [mode]
      normal_main = { fg = "${colors.base02}", bg = "${colors.base0D}", bold = true }
      normal_alt  = { fg = "${colors.base0D}", bg = "${colors.base02}" }
      select_main = { fg = "${colors.base02}", bg = "${colors.base0C}", bold = true }
      select_alt  = { fg = "${colors.base0C}", bg = "${colors.base02}" }
      unset_main  = { fg = "${colors.base02}", bg = "${colors.base09}", bold = true }
      unset_alt   = { fg = "${colors.base09}", bg = "${colors.base02}" }

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
      border  = { fg = "${colors.base08}" }
      title   = { fg = "${colors.base08}", bold = true }
      body    = { fg = "${colors.base05}" }
      list    = { fg = "${colors.base05}" }
      btn_yes = { fg = "${colors.base02}", bg = "${colors.base08}", bold = true }
      btn_no  = { fg = "${colors.base05}", bg = "${colors.base02}" }

      [pick]
      border   = { fg = "${colors.base0C}" }
      active   = { fg = "${colors.base0C}", bold = true }
      inactive = { fg = "${colors.base05}" }

      [input]
      border   = { fg = "${colors.base09}" }
      title    = { fg = "${colors.base09}" }
      value    = { fg = "${colors.base05}" }
      selected = { reversed = true }

      [cmp]
      border   = { fg = "${colors.base0F}" }
      active   = { fg = "${colors.base02}", bg = "${colors.base0F}" }
      inactive = { fg = "${colors.base05}" }

      [tasks]
      border  = { fg = "${colors.base0B}" }
      title   = { fg = "${colors.base0B}" }
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
      footer  = { fg = "${colors.base02}", bg = "${colors.base0D}" }

      [spot]
      border   = { fg = "${colors.base09}" }
      title    = { fg = "${colors.base09}" }
      tbl_cell = { fg = "${colors.base05}", bg = "${colors.base02}" }

      [icon]
      dirs = []
      prepend_conds = [
        { if = "dir & hovered", text = "󰝰", fg = "${colors.base0E}" },
        { if = "dir",           text = "󰉋", fg = "${colors.base0E}" },
      ]

      [filetype]
      rules = [
        { mime = "image/*", fg = "${colors.base05}" },
        { mime = "video/*", fg = "${colors.base0F}" },
        { mime = "audio/*", fg = "${colors.base0C}" },
        { mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}", fg = "${colors.base0A}" },
        { mime = "application/{pdf,doc,rtf}", fg = "${colors.base05}" },
        { mime = "vfs/{absent,stale}", fg = "${colors.base04}" },
        { url = "*/", fg = "${colors.base05}" },
        { url = "*", fg = "${colors.base05}" },
      ]
    '';
  };
}
