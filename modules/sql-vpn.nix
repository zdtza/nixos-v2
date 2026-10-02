# Route the Azure SQL private subnet through a SOCKS proxy provided by the Windows VM.
{ pkgs, ... }:

let
  pmisSql = pkgs.writeShellApplication {
    name = "pmis-sql";
    runtimeInputs = [ pkgs.sqlcmd ];
    text = ''
      if [[ -z "''${PMIS_SQL_PASSWORD:-}" ]]; then
        echo "PMIS_SQL_PASSWORD is not set" >&2
        exit 1
      fi

      export SQLCMDPASSWORD="$PMIS_SQL_PASSWORD"
      exec sqlcmd -S tcp:pmis-dev-sql.7946631b206b.database.windows.net,1433 -d PMVR -U SsetaDB -C -b "$@"
    '';
  };
in
{
  environment.systemPackages = with pkgs; [
    pmisSql
    sqlcmd
    tun2socks
  ];

  systemd.services.sql-vpn-tun = {
    description = "Route Azure SQL through the Windows VPN SOCKS proxy";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    path = [ pkgs.iproute2 ];

    preStart = ''
      ip link delete sql-vpn 2>/dev/null || true
      ip tuntap add mode tun dev sql-vpn
      ip address add 198.18.0.1/30 dev sql-vpn
      ip link set dev sql-vpn up
      ip route replace 10.0.4.0/24 dev sql-vpn
    '';

    serviceConfig = {
      ExecStart = "${pkgs.tun2socks}/bin/tun2socks --device tun://sql-vpn --proxy socks5://127.0.0.1:1080 --loglevel warn";
      Restart = "on-failure";
      RestartSec = 2;
    };

    postStop = ''
      ip link delete sql-vpn 2>/dev/null || true
    '';
  };
}
