{
  config,
  pkgs,
  ...
}:

# Screen recording, with or without a webcam overlay, saved to ~/Videos.
let
  # Matched by the Hyprland window rule that floats and pins it
  # (config/hypr/hyprland.lua).
  webcamAppId = "screen-record-webcam";

  # gpu-screen-recorder guesses the NVENC API its FFmpeg needs from the FFmpeg
  # major version (FFmpeg 9 -> 13.1) and refuses to encode on older drivers.
  # nixpkgs builds FFmpeg against nv-codec-headers 12.1, so 12.1 is the real
  # requirement, which the 595 driver (API 13.0) meets.
  gpuScreenRecorder = pkgs.gpu-screen-recorder.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/codec_query/nvenc.c \
        --replace-fail "NVENCAPI_PACKED_VERSION(13, 1)" "NVENCAPI_PACKED_VERSION(12, 1)"
    '';
  });

  # Toggles a recording: a second run stops the one in progress.
  # The portal picker chooses a monitor, window or region; with --webcam a
  # floating webcam window opens first, to be dragged wherever it should sit.
  screenRecord = pkgs.writeShellApplication {
    name = "screen-record";
    runtimeInputs = [
      gpuScreenRecorder
      pkgs.mpv
      pkgs.libnotify
      pkgs.coreutils
      pkgs.xdg-utils
    ];
    text = ''
      state="''${XDG_RUNTIME_DIR:-/tmp}/screen-record"
      pidfile="$state/recorder.pid"

      if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
        # SIGINT makes gpu-screen-recorder finish and close the file.
        kill -INT "$(cat "$pidfile")"
        exit 0
      fi
      # --stop (the bar's recording indicator) only ends a recording.
      if [ "''${1:-}" = "--stop" ]; then
        exit 0
      fi

      dir="${config.home.homeDirectory}/Videos"
      mkdir -p "$state" "$dir"
      file="$dir/screen-recording-$(date +%Y%m%d-%H%M%S).mp4"

      webcam_pid=""
      cleanup() {
        if [ -n "$webcam_pid" ]; then kill "$webcam_pid" 2>/dev/null || true; fi
        rm -f "$pidfile"
      }
      trap cleanup EXIT

      if [ "''${1:-}" = "--webcam" ]; then
        # Centre-cropped to a square, as large as the camera's height allows.
        mpv --no-config --really-quiet \
          --wayland-app-id=${webcamAppId} --title=Webcam \
          --vf=crop=ih:ih --autofit=360x360 \
          --profile=low-latency --untimed --no-cache \
          --no-osc --osd-level=0 --no-audio \
          av://v4l2:/dev/video0 &
        webcam_pid=$!
        # Let the window map before the picker, so it can be placed and is
        # already on screen when capture starts.
        sleep 1
      fi

      # AAC rather than the default Opus, which many editors and phones reject in MP4.
      gpu-screen-recorder -w portal -c mp4 -f 60 \
        -a "default_output|default_input" -ac aac -o "$file" &
      recorder_pid=$!
      echo "$recorder_pid" >"$pidfile"

      # Wait out the picker: the file appears once capture has started.
      while kill -0 "$recorder_pid" 2>/dev/null && [ ! -e "$file" ]; do
        sleep 0.2
      done
      started=false
      if [ -e "$file" ]; then started=true; fi

      wait "$recorder_pid" || true
      cleanup
      trap - EXIT

      if [ -s "$file" ]; then
        action=$(notify-send --app-name="Screen Recorder" -t 8000 \
          --action=default=Open --action=open=Open --action=folder="Show folder" \
          "Recording saved" "$(basename "$file")") || true
        case "$action" in
          default | open) xdg-open "$file" ;;
          folder) xdg-open "$dir" ;;
        esac
      else
        # Cancelled in the picker, or capture failed before any frame.
        rm -f "$file"
        if [ "$started" = true ]; then
          notify-send --app-name="Screen Recorder" -t 4000 "Recording failed"
        fi
      fi
    '';
  };
in
{
  home.packages = [ screenRecord ];

  xdg.desktopEntries = {
    screen-record = {
      name = "Record Screen";
      comment = "Record a monitor, window or region; stop from the bar or run again";
      exec = "screen-record";
      icon = "media-record";
      # X-Windowless: no window opens, so the Quickshell launcher shows no
      # launching spinner for it.
      categories = [
        "AudioVideo"
        "Recorder"
        "X-Windowless"
      ];
    };

    screen-record-webcam = {
      name = "Record Screen with Webcam";
      comment = "Record with a movable webcam overlay; stop from the bar or run again";
      exec = "screen-record --webcam";
      icon = "camera-web";
      # X-Windowless: no window opens, so the Quickshell launcher shows no
      # launching spinner for it.
      categories = [
        "AudioVideo"
        "Recorder"
        "X-Windowless"
      ];
    };
  };
}
