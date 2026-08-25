{ config, ... }:

# Single source of truth for where this repo lives on disk. Dotfiles are linked
# out of the nix store (mkOutOfStoreSymlink) so edits in the checkout apply
# immediately, without a rebuild. Only generated files (anything embedding
# stylix colors or store paths) stay in the store.
let
  repoPath = "/home/zdtza/.src/nixos";
in
{
  _module.args = {
    inherit repoPath;

    # repoFile "config/nvim" -> live symlink to <repo>/config/nvim
    repoFile = relativePath: config.lib.file.mkOutOfStoreSymlink "${repoPath}/${relativePath}";
  };
}
