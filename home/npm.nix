{ ... }:

{
  # NPM_TOKEN comes from ~/.config/Nixodus/.env, hydrated into the shell.
  # npm resolves ${VAR} itself at read time - no secret in the nix store.
  # this way .envs are not exposed to every terminal session
  home.file.".npmrc".text = ''
    //registry.npmjs.org/:_authToken=''${NPM_TOKEN}
  '';
}
