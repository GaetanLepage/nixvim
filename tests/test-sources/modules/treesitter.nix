{ pkgs }:
{
  # Minimal: enable the module with no languages configured.
  # Should produce no Lua output and no extra files.
  empty = {
    treesitter.enable = true;
  };

  # Enable highlighting for a single language (the most common use case).
  highlight-only =
    { config, lib, ... }:
    {
      treesitter = {
        enable = true;
        languages.rust.enable = true;
      };

      assertions = [
        {
          assertion = config.extraFiles ? "after/ftplugin/rust.lua";
          message = "Expected after/ftplugin/rust.lua to be generated";
        }
        {
          assertion = lib.hasInfix "vim.treesitter.start()" config.extraFiles."after/ftplugin/rust.lua".text;
          message = "Expected ftplugin to contain vim.treesitter.start()";
        }
        {
          assertion = !(lib.hasInfix "foldexpr" config.extraFiles."after/ftplugin/rust.lua".text);
          message = "Expected ftplugin to NOT contain foldexpr (folds disabled by default)";
        }
      ];
    };

  # Enable both highlighting and folding.
  highlight-and-folds =
    { config, lib, ... }:
    {
      treesitter = {
        enable = true;
        languages.rust = {
          enable = true;
          folds.enable = true;
        };
      };

      assertions = [
        {
          assertion = lib.hasInfix "vim.treesitter.start()" config.extraFiles."after/ftplugin/rust.lua".text;
          message = "Expected ftplugin to contain vim.treesitter.start()";
        }
        {
          assertion = lib.hasInfix "vim.wo[0][0].foldexpr" config.extraFiles."after/ftplugin/rust.lua".text;
          message = "Expected ftplugin to contain foldexpr";
        }
        {
          assertion = lib.hasInfix "vim.wo[0][0].foldmethod" config.extraFiles."after/ftplugin/rust.lua".text;
          message = "Expected ftplugin to contain foldmethod";
        }
      ];
    };

  # Test custom filetypes with vim.treesitter.language.register().
  filetypes =
    { config, lib, ... }:
    {
      treesitter = {
        enable = true;
        languages.nu = {
          enable = true;
          package = pkgs.vimPlugins.nvim-treesitter.builtGrammars.nix; # Use nix grammar as stand-in
          filetypes = [ "nu" ];
        };
      };

      assertions = [
        {
          assertion = config.extraFiles ? "after/ftplugin/nu.lua";
          message = "Expected after/ftplugin/nu.lua for the declared filetype";
        }
        {
          assertion = lib.hasInfix "vim.treesitter.language.register" config.treesitter.luaConfig.content;
          message = "Expected language.register() call in Lua config";
        }
      ];
    };

  # Test the "*" wildcard: setting folds.enable on "*" should be inherited.
  star-defaults =
    { config, lib, ... }:
    {
      treesitter = {
        enable = true;
        languages = {
          "*".folds.enable = true;
          rust.enable = true;
        };
      };

      assertions = [
        {
          assertion = lib.hasInfix "vim.wo[0][0].foldexpr" config.extraFiles."after/ftplugin/rust.lua".text;
          message = "Expected foldexpr to be inherited from '*' defaults";
        }
      ];
    };

  # Test the global treesitter.folds.enable default.
  global-folds-default =
    { config, lib, ... }:
    {
      treesitter = {
        enable = true;
        folds.enable = true;
        languages.rust.enable = true;
      };

      assertions = [
        {
          assertion = lib.hasInfix "vim.wo[0][0].foldexpr" config.extraFiles."after/ftplugin/rust.lua".text;
          message = "Expected foldexpr to be inherited from global folds.enable";
        }
      ];
    };

  # Test that per-language setting overrides the global default.
  per-language-override =
    { config, lib, ... }:
    {
      treesitter = {
        enable = true;
        folds.enable = true;
        languages.rust = {
          enable = true;
          folds.enable = false;
        };
      };

      assertions = [
        {
          assertion = !(lib.hasInfix "foldexpr" config.extraFiles."after/ftplugin/rust.lua".text);
          message = "Expected per-language folds.enable=false to override global default";
        }
      ];
    };

  # Test explicit opt-out: enable a language but disable highlighting.
  # Should emit vim.treesitter.stop(0) in the ftplugin.
  disable-highlight =
    { config, lib, ... }:
    {
      treesitter = {
        enable = true;
        languages.lua = {
          enable = true;
          highlight.enable = false;
        };
      };

      assertions = [
        {
          assertion = lib.hasInfix "vim.treesitter.stop(0)" config.extraFiles."after/ftplugin/lua.lua".text;
          message = "Expected vim.treesitter.stop(0) when both highlight and folds are disabled";
        }
      ];
    };

  # Test query extension: should prepend "; extends".
  query-extend =
    { config, lib, ... }:
    {
      treesitter = {
        enable = true;
        languages.markdown = {
          enable = true;
          queries.injections.extend = ''
            ; custom injection rule
            ((code_fence_content) @injection.content)
          '';
        };
      };

      assertions = [
        {
          assertion = config.extraFiles ? "queries/markdown/injections.scm";
          message = "Expected queries/markdown/injections.scm to be generated";
        }
        {
          assertion = lib.hasPrefix "; extends\n" config.extraFiles."queries/markdown/injections.scm".text;
          message = "Expected query file to start with '; extends'";
        }
        {
          assertion =
            lib.hasInfix "custom injection rule"
              config.extraFiles."queries/markdown/injections.scm".text;
          message = "Expected query file to contain the user's content";
        }
      ];
    };

  # Test query replacement.
  query-replace =
    { config, lib, ... }:
    {
      treesitter = {
        enable = true;
        languages.rust = {
          enable = true;
          queries.highlights.replace = ''
            ; custom highlights
            (identifier) @variable
          '';
        };
      };

      assertions = [
        {
          assertion = config.extraFiles ? "queries/rust/highlights.scm";
          message = "Expected queries/rust/highlights.scm to be generated";
        }
        {
          assertion = !(lib.hasPrefix "; extends" config.extraFiles."queries/rust/highlights.scm".text);
          message = "Expected replacement query NOT to have '; extends' prefix";
        }
        {
          assertion = lib.hasInfix "custom highlights" config.extraFiles."queries/rust/highlights.scm".text;
          message = "Expected query file to contain replacement content";
        }
      ];
    };

  # Test query disable: should produce an empty file.
  query-disable =
    { config, lib, ... }:
    {
      treesitter = {
        enable = true;
        languages.rust = {
          enable = true;
          queries.injections.disable = true;
        };
      };

      assertions = [
        {
          assertion = config.extraFiles ? "queries/rust/injections.scm";
          message = "Expected queries/rust/injections.scm to be generated";
        }
        {
          assertion = config.extraFiles."queries/rust/injections.scm".text == "";
          message = "Expected disabled query file to be empty";
        }
      ];
    };

  # Verify that each query type allows setting exactly one override mode.
  # Each query type has a different mode set; all should produce valid files.
  query-single-mode =
    { config, lib, ... }:
    {
      treesitter = {
        enable = true;
        languages.rust = {
          enable = true;
          # Only one query override mode set per type — should pass assertions.
          queries.highlights.replace = "; custom highlights";
          queries.injections.extend = "; extra injections";
          queries.folds.disable = true;
        };
      };

      assertions = [
        {
          assertion = config.extraFiles ? "queries/rust/highlights.scm";
          message = "Expected queries/rust/highlights.scm (replace mode)";
        }
        {
          assertion = config.extraFiles ? "queries/rust/injections.scm";
          message = "Expected queries/rust/injections.scm (extend mode)";
        }
        {
          assertion = config.extraFiles ? "queries/rust/folds.scm";
          message = "Expected queries/rust/folds.scm (disable mode)";
        }
        {
          assertion = lib.hasPrefix "; extends\n" config.extraFiles."queries/rust/injections.scm".text;
          message = "Expected injections.scm to have '; extends' prefix";
        }
        {
          assertion = config.extraFiles."queries/rust/folds.scm".text == "";
          message = "Expected folds.scm to be empty (disabled)";
        }
      ];
    };

  # Test multiple languages enabled at once.
  multiple-languages =
    { config, lib, ... }:
    {
      treesitter = {
        enable = true;
        languages = {
          rust.enable = true;
          python.enable = true;
          nix.enable = true;
        };
      };

      assertions = [
        {
          assertion = config.extraFiles ? "after/ftplugin/rust.lua";
          message = "Expected after/ftplugin/rust.lua";
        }
        {
          assertion = config.extraFiles ? "after/ftplugin/python.lua";
          message = "Expected after/ftplugin/python.lua";
        }
        {
          assertion = config.extraFiles ? "after/ftplugin/nix.lua";
          message = "Expected after/ftplugin/nix.lua";
        }
      ];
    };

  # Test that the module does nothing when treesitter.enable = false (default).
  disabled =
    { config, lib, ... }:
    {
      test.buildNixvim = false;

      treesitter.languages.rust.enable = true;

      assertions = [
        {
          assertion = !(config.extraFiles ? "after/ftplugin/rust.lua");
          message = "Expected no ftplugin files when treesitter.enable is false";
        }
      ];
    };
}
