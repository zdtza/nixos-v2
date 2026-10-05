{ pkgs, ... }:

let
  # fetching the base English model for voice recognition, larger models are too slow.
  model = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
    hash = "sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=";
  };
  # defining config for voice to text as toml.
  configFile = (pkgs.formats.toml { }).generate "voxtype-config.toml" {
    state_file = "auto";
    hotkey.enabled = false;

    audio = {
      device = "default";
      sample_rate = 16000;
      max_duration_secs = 120;
      pause_media = true;
      feedback = {
        enabled = false;
        theme = "subtle";
        volume = 0.7;
      };
    };

    whisper = {
      model = toString model;
      language = "en";
      translate = false;
      on_demand_loading = false;
    };

    output = {
      mode = "type";
      fallback_to_clipboard = true;
      type_delay_ms = 1;
      pre_type_delay_ms = 100;
      notification = {
        on_recording_start = false;
        on_recording_stop = false;
        on_transcription = false;
      };
    };

    text.spoken_punctuation = false;
  };
in
{
  # On PATH for the Hyprland and Quickshell dictation controls; the daemon runs from modules/home/services.nix.
  home.packages = [ pkgs.voxtype-vulkan ];

  xdg.configFile."voxtype/config.toml".source = configFile;
}
