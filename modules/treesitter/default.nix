# Top-level tree-sitter module.
#
# Provides Nix-provisioned, core-API-only tree-sitter integration for Neovim,
# without any dependency on the archived `nvim-treesitter` plugin.
#
# Parsers and queries are installed from nixpkgs derivations at build time.
# At runtime the module generates:
#   - `vim.treesitter.start()` calls via ftplugin files
#   - `vim.treesitter.foldexpr()` window-local settings
#   - `vim.treesitter.language.register()` calls for filetype mappings
#
# See also: `plugins.treesitter` for the legacy module wrapping nvim-treesitter.
{ lib, config, ... }:
let
  cfg = config.treesitter;

  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
in
{
  options.treesitter = {
    enable = mkEnableOption ''
      Neovim's built-in tree-sitter integration.

      This module is independent of the `nvim-treesitter` plugin.
      It uses only Neovim core APIs (`vim.treesitter.start()`,
      `vim.treesitter.foldexpr()`, `vim.treesitter.language.register()`)
      and Nix-provisioned grammar packages.

      Indentation is not supported in this module. If you need tree-sitter
      indentation, use `plugins.treesitter` (the legacy module) instead.
    '';

    highlight.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable tree-sitter syntax highlighting by default for all configured languages.

        This is the global default. Per-language overrides via
        `treesitter.languages.<name>.highlight.enable` take precedence,
        followed by `treesitter.languages."*".highlight.enable`.
      '';
    };

    folds.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable tree-sitter-based folding by default for all configured languages.

        Sets `foldexpr` and `foldmethod` window-locally in the generated ftplugin.

        This is the global default. Per-language overrides via
        `treesitter.languages.<name>.folds.enable` take precedence,
        followed by `treesitter.languages."*".folds.enable`.
      '';
    };

    luaConfig = mkOption {
      type = types.pluginLuaConfig;
      default = { };
      description = ''
        Lua code for tree-sitter configuration.
      '';
      visible = false;
      internal = true;
    };
  };

  imports = [
    ./languages
  ];

  config = mkIf cfg.enable {
    # Emit language.register() calls in extraConfigLuaPre so they run
    # before any buffer is loaded.
    extraConfigLuaPre = mkIf (cfg.luaConfig.content != "") ''
      -- Treesitter {{{
      do
        ${cfg.luaConfig.content}
      end
      -- }}}
    '';
  };
}
