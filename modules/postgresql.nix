# Local PostgreSQL development database running in Docker.
{ ... }:
{
  virtualisation = {
    docker.enable = true;
    oci-containers = {
      backend = "docker";
      containers.postgresql-development = {
        image = "postgres:17";
        autoStart = true;
        environment = {
          POSTGRES_DB = "development";
          POSTGRES_USER = "postgres";
          POSTGRES_PASSWORD = "postgres";
        };
        volumes = [ "/var/lib/postgresql-development:/var/lib/postgresql/data" ];
        ports = [ "127.0.0.1:5432:5432" ];
      };
    };
  };

  # The official image runs PostgreSQL as uid/gid 999.
  systemd.tmpfiles.rules = [ "d /var/lib/postgresql-development 0700 999 999 -" ];
}
