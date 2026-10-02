{ ... }:

let
  gitHost = identityFile: {
    User = "git";
    IdentityFile = identityFile;
    IdentitiesOnly = true;
    AddKeysToAgent = "yes";
  };
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      # Create: `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519`; copy with `wl-copy < ~/.ssh/id_ed25519.pub`.
      "github.com" = gitHost "~/.ssh/id_ed25519";
      "gitlab.com" = gitHost "~/.ssh/id_ed25519";

      # Create: `ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_azure`; copy with `wl-copy < ~/.ssh/id_rsa_azure.pub`.
      "ssh.dev.azure.com" = gitHost "~/.ssh/id_rsa_azure";

      "pmis-windows-vpn" = {
        HostName = "127.0.0.1";
        User = "zdtza";
        Port = 2222;
        DynamicForward = "127.0.0.1:1080";
        ExitOnForwardFailure = true;
        ServerAliveInterval = 30;
        ServerAliveCountMax = 3;
      };
    };
  };

  # Replace the old manually-created config on the first activation.
  home.file.".ssh/config".force = true;
}
