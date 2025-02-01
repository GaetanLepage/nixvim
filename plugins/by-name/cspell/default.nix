{
  lib,
  config,
  ...
}:
lib.nixvim.plugins.mkNeovimPlugin {
  name = "cspell";
  packPathName = "cspell.nvim";
  package = "cspell-nvim";

  maintainers = [ lib.maintainers.GaetanLepage ];

  # TODO: null-ls integration
  settingsExample = {

  };

  callSetup = false;
  extraConfig = cfg: {
    assertions = lib.nixvim.mkAssertions "plugins.cspell" {
      assertion = config.plugins.none-ls.enable;
      message = ''
        You have enabled the cspell plugin which requires none-ls.
        Please, enable `plugins.none-ls` to use this plugin.
      '';
    };

    # plugins.none-ls.sources = [
    #   { __raw = "require('cspell').diagnostics.with({ config = ${toLuaObject cfg.settings} })"; }
    #   { __raw = "require('cspell').code_actions.with({ config = ${toLuaObject cfg.settings} })"; }
    # ];
  };
}
