{ pkgs, ... }:

let
  package = pkgs.voxtype-vulkan;
  # other models are too slow to be useful
  model = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
    hash = "sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=";
  };
  # needs to be generated as model is inserted at runtime based on above selection
  configFile = (pkgs.formats.toml { }).generate "voxtype-config.toml" {
    state_file = "auto";
    hotkey.enabled = false;

    audio = {
      device = "default";
      sample_rate = 16000;
      max_duration_secs = 60;
      pause_media = true;
      feedback = {
        enabled = true;
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
  home.packages = [ package ];

  xdg.configFile."voxtype/config.toml".source = configFile;

  systemd.user.services.voxtype = {
    Unit = {
      Description = "Voxtype voice-to-text daemon";
      PartOf = [ "graphical-session.target" ];
      After = [
        "graphical-session.target"
        "pipewire.service"
        "pipewire-pulse.service"
      ];
    };

    Service = {
      ExecStart = "voxtype daemon";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
