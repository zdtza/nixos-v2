{
  config,
  lib,
  pkgs,
  ...
}:

# SQL Server for Linux in Docker, with a command to restore any .bak on demand.
let
  cfg = config.sqlServer;
  unit = "docker-mssql.service";
  # Host directory the container reads backups from while restoring.
  dropPath = "/var/lib/mssql-backups";
  dropMount = "/var/opt/mssql/restore";

  restore = pkgs.writeShellApplication {
    name = "mssql-restore";
    runtimeInputs = with pkgs; [
      coreutils
      sqlcmd
      systemd
      zenity
    ];
    text = ''
      usage() {
        echo 'usage: mssql-restore [backup-file] [database-name]'
        echo 'Without a file, opens a file picker. The name defaults to the one stored in the backup.'
      }
      [[ ''${1-} == -h || ''${1-} == --help ]] && { usage; exit 0; }

      export SQLCMDPASSWORD=${lib.escapeShellArg cfg.password}
      sql() {
        sqlcmd -S "127.0.0.1,${toString cfg.port}" -U sa -C -b -h -1 -W -s '|' -Q "SET NOCOUNT ON; $1"
      }

      source=''${1-}
      if [[ -z $source ]]; then
        source=$(zenity --file-selection --title='Pick a SQL Server backup' --filename="$HOME/") || exit 0
      fi
      if [[ ! -f $source ]]; then
        echo "mssql-restore: $source is not a file" >&2
        exit 1
      fi

      if ! systemctl is-active --quiet ${unit}; then
        echo 'Starting SQL Server...'
        systemctl start ${unit}
      fi
      # The first start pulls the image, so allow a slow download.
      deadline=$((SECONDS + 3600))
      until sql 'SELECT 1' >/dev/null 2>&1; do
        if (( SECONDS >= deadline )); then
          echo 'mssql-restore: SQL Server is not accepting connections; check journalctl -u ${unit}' >&2
          exit 1
        fi
        sleep 3
      done

      name="restore-$$.bak"
      cleanup() { rm -f ${dropPath}/"$name"; }
      trap cleanup EXIT
      cp -- "$source" ${dropPath}/"$name"
      chmod 0644 ${dropPath}/"$name"
      bak="${dropMount}/$name"

      # Column 10 of HEADERONLY is the database name the backup was taken from.
      if ! header=$(sql "RESTORE HEADERONLY FROM DISK = N'$bak'" 2>&1); then
        echo "mssql-restore: $source is not a readable SQL Server backup" >&2
        echo "$header" >&2
        exit 1
      fi
      db=''${2:-$(cut -d'|' -f10 <<<"''${header%%$'\n'*}")}
      if [[ ! $db =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo "mssql-restore: '$db' is not a valid database name; pass one as the second argument" >&2
        exit 1
      fi

      replace=""
      if [[ $(sql "SELECT DB_ID(N'$db')") != NULL ]]; then
        read -r -p "Database $db already exists. Overwrite it? [y/N] " reply
        [[ $reply == [Yy]* ]] || exit 0
        # Disconnect open sessions so the restore can take the database.
        sql "ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE"
        replace="REPLACE, "
      fi

      # Backups carry their original (often Windows) file paths, so move every file into the data dir.
      moves=""
      while IFS='|' read -r logical _ type _; do
        [[ -n $logical ]] || continue
        case $type in
          L) ext=ldf ;;
          *) ext=$([[ -z $moves ]] && echo mdf || echo ndf) ;;
        esac
        moves+="MOVE N'$logical' TO N'/var/opt/mssql/data/''${db}_''${logical}.$ext', "
      done < <(sql "RESTORE FILELISTONLY FROM DISK = N'$bak'")

      echo "Restoring $source as $db..."
      if ! sql "RESTORE DATABASE [$db] FROM DISK = N'$bak' WITH $moves$replace RECOVERY"; then
        [[ -n $replace ]] && sql "ALTER DATABASE [$db] SET MULTI_USER" || true
        exit 1
      fi
      sql "ALTER DATABASE [$db] SET MULTI_USER"
      echo "Restored $db. Connect with Server=localhost,${toString cfg.port};Database=$db;User Id=sa;TrustServerCertificate=True"
    '';
  };
in
{
  options.sqlServer = {
    user = lib.mkOption {
      type = lib.types.str;
      description = "User allowed to start and stop SQL Server and restore backups.";
    };
    # Must meet SQL Server's complexity rules or the container exits on first start.
    password = lib.mkOption {
      type = lib.types.str;
      default = "LocalDev!2026";
      description = "sa password; stored in the Nix store, so local development only.";
    };
    imageTag = lib.mkOption {
      type = lib.types.str;
      default = "2022-latest";
      description = "Backups only restore onto the same or a newer major version.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 1433;
    };
    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    dataPath = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/mssql";
      description = "Persistent /var/opt/mssql directory.";
    };
  };

  config = {
    virtualisation = {
      docker.enable = true;
      oci-containers = {
        backend = "docker";
        containers.mssql = {
          image = "mcr.microsoft.com/mssql/server:${cfg.imageTag}";
          inherit (cfg) autoStart;
          environment = {
            ACCEPT_EULA = "Y";
            MSSQL_SA_PASSWORD = cfg.password;
            MSSQL_PID = "Developer";
            TZ = config.time.timeZone;
          };
          volumes = [
            "${cfg.dataPath}:/var/opt/mssql"
            "${dropPath}:${dropMount}:ro"
          ];
          ports = [ "127.0.0.1:${toString cfg.port}:1433" ];
        };
      };
    };

    systemd.tmpfiles.rules = [
      # The image runs as the non-root mssql user (uid 10001).
      "d ${cfg.dataPath} 0700 10001 0 -"
      "d ${dropPath} 0755 ${cfg.user} ${config.users.users.${cfg.user}.group} -"
    ];

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.user == "${cfg.user}" &&
            action.lookup("unit") == "${unit}")
          return polkit.Result.YES;
      });
    '';

    users.users.${cfg.user}.packages = [
      restore
      pkgs.sqlcmd
    ];
  };
}
