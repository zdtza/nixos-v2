{ config, ... }:

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
      cwd             = { fg = "@accent@" }
      find_keyword    = { fg = "@yellow@", bold = true, underline = true }
      find_position   = { fg = "@foreground@", bg = "reset", bold = true }
      marker_copied   = { fg = "@green@",  bg = "@green@" }
      marker_cut      = { fg = "@red@",    bg = "@red@" }
      marker_marked   = { fg = "@cyan@",   bg = "@cyan@" }
      marker_selected = { fg = "@yellow@", bg = "@yellow@" }
      count_copied    = { bg = "@green@" }
      count_cut       = { bg = "@red@" }
      count_selected  = { bg = "@yellow@" }
      border_symbol   = "│"
      border_style    = { fg = "@muted@" }

      [indicator]
      parent  = { fg = "@bright_foreground@", bg = "@selection@" }
      current = { fg = "@bright_foreground@", bg = "@selection@", bold = true }
      preview = { fg = "@bright_foreground@", bg = "@selection@" }
      padding = { open = "▐", close = "▌" }

      [tabs]
      active    = { fg = "@selection@", bg = "@accent@", bold = true }
      inactive  = { fg = "@accent@", bg = "@selection@" }
      sep_inner = { open = " ", close = " " }
      sep_outer = { open = " ", close = " " }

      [mode]
      normal_main = { fg = "@selection@", bg = "@accent@", bold = true }
      normal_alt  = { fg = "@accent@", bg = "@selection@" }
      select_main = { bg = "@cyan@",   bold = true }
      select_alt  = { fg = "@cyan@",   bg = "@selection@" }
      unset_main  = { bg = "@foreground@", bold = true }
      unset_alt   = { fg = "@foreground@", bg = "@selection@" }

      [status]
      sep_left  = { open = " ", close = " " }
      sep_right = { open = " ", close = " " }
      perm_sep        = { fg = "@muted@" }
      perm_type       = { fg = "@accent@" }
      perm_read       = { fg = "@yellow@" }
      perm_write      = { fg = "@red@" }
      perm_exec       = { fg = "@green@" }
      progress_label  = { fg = "@foreground@", bold = true }
      progress_normal = { fg = "@green@", bg = "@selection@" }
      progress_error  = { fg = "@yellow@", bg = "@red@" }

      [confirm]
      border  = { fg = "@accent@" }
      title   = { fg = "@accent@", bold = true }
      body    = { fg = "@foreground@" }
      list    = { fg = "@foreground@" }
      btn_yes = { fg = "@selection@", bg = "@accent@", bold = true }
      btn_no  = { fg = "@foreground@", bg = "@selection@" }

      [pick]
      border   = { fg = "@accent@" }
      active   = { fg = "@foreground@", bold = true }
      inactive = { fg = "@foreground@" }

      [input]
      border   = { fg = "@accent@" }
      title    = { fg = "@accent@" }
      value    = { fg = "@foreground@" }
      selected = { reversed = true }

      [cmp]
      border   = { fg = "@accent@" }
      active   = { fg = "@selection@", bg = "@accent@" }
      inactive = { fg = "@foreground@" }

      [tasks]
      border  = { fg = "@accent@" }
      title   = { fg = "@accent@" }
      hovered = { fg = "@foreground@", bold = true }

      [which]
      mask            = { bg = "@selection@" }
      rest            = { fg = "@muted@" }
      desc            = { fg = "@foreground@" }
      separator       = "  "
      separator_style = { fg = "@muted@" }

      [help]
      on      = { fg = "@cyan@" }
      run     = { fg = "@foreground@" }
      hovered = { reversed = true, bold = true }
      footer  = { bg = "@foreground@" }

      [spot]
      border   = { fg = "@accent@" }
      title    = { fg = "@accent@" }
      tbl_cell = { fg = "@foreground@", bg = "@selection@" }

      [icon]
      dirs = []
      prepend_conds = [
        { if = "dir & hovered", text = "󰝰", fg = "@accent@" },
        { if = "dir",           text = "󰉋", fg = "@accent@" },
      ]

      [filetype]
      rules = [
        { mime = "image/*", fg = "@foreground@" },
        { mime = "{audio,video}/*", fg = "@foreground@" },
        { mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}", fg = "@foreground@" },
        { mime = "application/{pdf,doc,rtf}", fg = "@foreground@" },
        { mime = "vfs/{absent,stale}", fg = "@foreground@" },
        { url = "*/", fg = "@foreground@" },
        { url = "*", fg = "@foreground@" },
      ]
    '';
  };
}
