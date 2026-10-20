{
  config,
  lib,
  ...
}:

# Jellyfin media server streaming ~/Media to phones and TVs on the LAN, transcoding on the NVIDIA GPU.
let
  cfg = config.jellyfin;
  group = config.users.users.${cfg.user}.group;
in
{
  options.jellyfin = {
    # Home directories are 0700, so Jellyfin runs as the owner to read media there.
    user = lib.mkOption {
      type = lib.types.str;
      description = "User Jellyfin runs as; must be able to read the media folders.";
    };
    mediaPath = lib.mkOption {
      type = lib.types.str;
      default = "${config.users.users.${cfg.user}.home}/Media";
      defaultText = lib.literalExpression ''"''${home}/Media"'';
      description = "Root folder holding one subfolder per Jellyfin library.";
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open Jellyfin's web and discovery ports to the local network.";
    };
  };

  config = {
    services.jellyfin = {
      enable = true;
      inherit (cfg) user openFirewall;
      inherit group;

      hardwareAcceleration = {
        enable = true;
        type = "nvenc";
        device = "/dev/nvidia0";
      };
      # Keep transcoding settings here; dashboard edits are reset on restart.
      forceEncodingConfig = true;
      transcoding = {
        enableHardwareEncoding = true;
        # Everything the GTX 1650's NVDEC can decode.
        hardwareDecodingCodecs = {
          h264 = true;
          hevc = true;
          hevc10bit = true;
          mpeg2 = true;
          vc1 = true;
          vp8 = true;
          vp9 = true;
        };
        hardwareEncodingCodecs.hevc = true;
      };
    };

    systemd.services.jellyfin.serviceConfig = {
      # NVENC also needs the control and memory devices next to /dev/nvidia0.
      DeviceAllow = [
        "/dev/nvidiactl rw"
        "/dev/nvidia-uvm rw"
        "/dev/nvidia-uvm-tools rw"
        "/dev/nvidia-modeset rw"
      ];
      # Hide the rest of /home; expose only the media folder, read-only.
      ProtectHome = "tmpfs";
      BindReadOnlyPaths = [ cfg.mediaPath ];
    };

    # One folder per Jellyfin library; point each library at its folder in the web UI.
    systemd.tmpfiles.rules = map (dir: "d '${cfg.mediaPath}/${dir}' 0755 ${cfg.user} ${group} -") [
      ""
      "TV Shows"
      "Movies"
    ];
  };
}
