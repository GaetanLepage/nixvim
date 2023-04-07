{
  pkgs,
  config,
  lib,
  ...
} @ args:
with lib; let
  helpers = import ../helpers.nix args;
in rec {
  sourceToConfigModule = {
    enable,
    package,
    extraPackages,
    sourceType,
    name,
    extraArgs,
  }:
    mkIf enable {
      # Does this evaluate package?
      extraPackages = extraPackages ++ optional (package != null) package;

      # Add source to list of sources
      plugins.null-ls.sourcesItems = let
        sourceItem = "${sourceType}.${name}";
        withArgs =
          if (isNull extraArgs)
          then sourceItem
          else "${sourceItem}.with ${extraArgs}";
        finalString = ''require("null-ls").builtins.${withArgs}'';
      in [(helpers.mkRaw finalString)];
    };

  mkServer = {
    name,
    sourceType,
    description ? "${name} source, for null-ls.",
    package ? null,
    extraPackages ? [],
    ...
  }:
  # returns a module
  {
    pkgs,
    config,
    lib,
    ...
  } @ args:
    with lib; let
      helpers = import ../helpers.nix args;
      cfg = config.plugins.null-ls.sources.${sourceType}.${name};
      # does this evaluate package?
      packageOption =
        if package == null
        then {}
        else {
          package = mkOption {
            type = types.package;
            default = package;
            description = "Package to use for ${name} by null-ls";
          };
        };
    in {
      options.plugins.null-ls.sources.${sourceType}.${name} =
        {
          enable = mkEnableOption description;

          # TODO: withArgs can exist outside of the module in a generalized manner
          withArgs =
            helpers.mkNullOrOption types.str
            "Raw Lua code to be called with the with function";
          # Not sure that it makes sense to have the same example for all servers
          # example = ''
          #   '\'{ extra_args = { "--no-semi", "--single-quote", "--jsx-single-quote" } }'\'
          # '';
        }
        // packageOption;

      config = sourceToConfigModule {
        inherit (cfg) enable;
        extraArgs = cfg.withArgs;
        package = helpers.ifNonNull' package cfg.package;
        inherit sourceType name extraPackages;
      };
    };
}
