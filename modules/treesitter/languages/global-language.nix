# The "*" wildcard language submodule.
#
# Unlike `language.nix`, this only exposes feature-toggle defaults
# (highlight, folds). It does not have `enable`, `package`, `filetypes`,
# `languageName`, or `queries`, because those concepts don't make sense
# for a wildcard entry.
{ lib, ... }:
let
  inherit (lib) types;
in
{
  options = {
    highlight.enable = lib.mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Default tree-sitter highlighting setting for all languages.

        When set, overrides the global `treesitter.highlight.enable`.
        Per-language `treesitter.languages.<name>.highlight.enable` still takes precedence.
      '';
    };

    folds.enable = lib.mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Default tree-sitter folding setting for all languages.

        When set, overrides the global `treesitter.folds.enable`.
        Per-language `treesitter.languages.<name>.folds.enable` still takes precedence.
      '';
    };
  };
}
