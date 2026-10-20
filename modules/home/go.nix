{ config, pkgs, ... }:

let
  goPath = "${config.xdg.dataHome}/go";
in
{
  programs.go = {
    enable = true;
    # Keep module cache and `go install` binaries out of ~/go.
    env.GOPATH = goPath;
    telemetry.mode = "off";
  };

  home = {
    # Editor tooling: VS Code's Go extension and nvim look for these on $PATH.
    packages = with pkgs; [
      gopls # language server
      delve # debugger (dlv)
      go-tools # staticcheck
      gotools # goimports etc.
    ];

    # Tools added with `go install` land here.
    sessionPath = [ "${goPath}/bin" ];
  };
}
