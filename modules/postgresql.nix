{
  config,
  lib,
  pkgs,
  ...
}:

# Local PostgreSQL development database running in Docker.
let
  cfg = config.development.postgresql;
  pgadmin = pkgs.pgadmin4-desktopmode;
  pgadminLauncher = pkgs.writeShellApplication {
    name = "pgadmin4-launch";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      xdg-utils
    ];
    text = ''
      url=http://127.0.0.1:5050
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/pgadmin4"
      mkdir -p "$state_dir"

      if ! curl --silent --fail --max-time 1 "$url/" >/dev/null; then
        nohup ${lib.getExe pgadmin} >>"$state_dir/server.log" 2>&1 &
        for _ in $(seq 1 30); do
          curl --silent --fail --max-time 1 "$url/" >/dev/null && break
          sleep 0.5
        done
      fi

      exec xdg-open "$url/"
    '';
  };
  pgadminDesktop = pkgs.makeDesktopItem {
    name = "pgadmin4";
    desktopName = "pgAdmin 4";
    comment = "PostgreSQL administration and development platform";
    exec = lib.getExe pgadminLauncher;
    icon = "${pgadmin.src}/pkg/linux/pgadmin4-128x128.png";
    categories = [
      "Development"
      "Database"
    ];
  };
in
{
  options.development.postgresql = {
    enable = lib.mkEnableOption "the PostgreSQL development container";

    image = lib.mkOption {
      type = lib.types.str;
      default = "postgres:17";
      description = "Docker image used for the PostgreSQL container.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5432;
      description = "Localhost port on which PostgreSQL is exposed.";
    };

    database = lib.mkOption {
      type = lib.types.str;
      default = "development";
      description = "Database created when the data directory is initialized.";
    };

    username = lib.mkOption {
      type = lib.types.str;
      default = "postgres";
      description = "Development database administrator username.";
    };

    password = lib.mkOption {
      type = lib.types.str;
      default = "postgres";
      description = "Development database password. Do not use this default for non-local deployments.";
    };

    dataPath = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/postgresql-development";
      description = "Host directory containing persistent PostgreSQL data.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation = {
      docker.enable = true;
      oci-containers = {
        backend = "docker";
        containers.postgresql-development = {
          image = cfg.image;
          autoStart = true;
          environment = {
            POSTGRES_DB = cfg.database;
            POSTGRES_USER = cfg.username;
            POSTGRES_PASSWORD = cfg.password;
          };
          volumes = [ "${cfg.dataPath}:/var/lib/postgresql/data" ];
          ports = [ "127.0.0.1:${toString cfg.port}:5432" ];
          extraOptions = [
            "--health-cmd=pg_isready -U ${cfg.username} -d ${cfg.database}"
            "--health-interval=5s"
            "--health-timeout=5s"
            "--health-retries=12"
          ];
        };
      };
    };

    # The official image runs PostgreSQL as uid/gid 999.
    systemd.tmpfiles.rules = [ "d ${cfg.dataPath} 0700 999 999 -" ];

    environment.systemPackages = [
      pkgs.postgresql_17
      pgadmin
      pgadminDesktop
      pgadminLauncher
    ];
  };
}
