# Per-language tree-sitter submodule.
#
# Usage: lib.modules.importApply ./language.nix { /*args*/ }
#
# Each attribute in `treesitter.languages` (except "*") gets this submodule.
_args:
{ lib, name, ... }:
let
  inherit (lib)
    types
    mkEnableOption
    mkOption
    ;

  mkQuerySubmodule =
    queryType:
    types.submodule {
      options = {
        replace = mkOption {
          type = types.nullOr types.lines;
          default = null;
          description = ''
            Replace the grammar-provided `${queryType}.scm` query file entirely.

            The replacement file is placed on the runtimepath before the grammar's
            queries, so Neovim picks it instead of the grammar's version.
          '';
        };

        extend = mkOption {
          type = types.nullOr types.lines;
          default = null;
          description = ''
            Extend the grammar-provided `${queryType}.scm` query file.

            The module automatically prepends `; extends` so Neovim merges this
            content with the grammar's file rather than replacing it.
          '';
        };

        disable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Disable the `${queryType}.scm` queries for this language by placing
            an empty file on the runtimepath before the grammar's version.
          '';
        };
      };
    };
in
{
  options = {
    enable = mkEnableOption "tree-sitter for ${name}";

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      defaultText = lib.literalMD "`pkgs.vimPlugins.nvim-treesitter.builtGrammars.${name}` if available";
      description = ''
        The grammar package for ${name}.

        Must be a derivation whose output contains `parser/<lang>.so`
        and optionally `queries/<lang>/*.scm`.

        When `null` (the default), the module resolves the package from
        `pkgs.vimPlugins.nvim-treesitter.builtGrammars.${name}`.

        Typical sources:
        - `pkgs.vimPlugins.nvim-treesitter.builtGrammars.<name>` (default, queries included)
        - `pkgs.tree-sitter-grammars.tree-sitter-<name>` (may not include queries)
        - A custom `pkgs.tree-sitter.buildGrammar { ... }` derivation
      '';
    };

    languageName = mkOption {
      type = types.str;
      default = name;
      description = ''
        The tree-sitter parser/language name. Defaults to the attribute name.

        Only set this when the parser name on disk differs from the attribute
        name you want to use in your config.
      '';
    };

    filetypes = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = ''
        Filetypes that should use this parser.

        When non-empty, the module generates a
        `vim.treesitter.language.register()` call so Neovim knows
        to use this parser for these filetypes.

        Leave empty when the parser name matches the filetype (the common case).
      '';
      example = [ "nu" ];
    };

    highlight.enable = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Enable tree-sitter highlighting for ${name}.

        When `null`, inherits from `treesitter.languages."*".highlight.enable`
        or `treesitter.highlight.enable`.
      '';
    };

    folds.enable = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Enable tree-sitter-based folding for ${name}.

        When `null`, inherits from `treesitter.languages."*".folds.enable`
        or `treesitter.folds.enable`.
      '';
    };

    queries = {
      highlights = mkOption {
        type = mkQuerySubmodule "highlights";
        default = { };
        description = "Override or extend the `highlights.scm` queries for ${name}.";
      };

      injections = mkOption {
        type = mkQuerySubmodule "injections";
        default = { };
        description = "Override or extend the `injections.scm` queries for ${name}.";
      };

      folds = mkOption {
        type = mkQuerySubmodule "folds";
        default = { };
        description = "Override or extend the `folds.scm` queries for ${name}.";
      };

      locals = mkOption {
        type = mkQuerySubmodule "locals";
        default = { };
        description = "Override or extend the `locals.scm` queries for ${name}.";
      };
    };
  };
}
