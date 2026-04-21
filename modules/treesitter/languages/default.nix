{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib) types;
  inherit (lib.nixvim) toLuaObject;

  tsCfg = config.treesitter;
  cfg = tsCfg.languages;

  # Create a submodule type from `language.nix`
  mkLanguageType =
    args:
    types.submoduleWith {
      shorthandOnlyDefinesConfig = true;
      modules = [
        (lib.modules.importApply ./language.nix args)
      ];
    };

  # Resolve the effective value of a feature toggle through the inheritance chain:
  #   per-language value ?? "*" value ?? global value
  resolveFeature =
    langValue: starValue: globalValue:
    if langValue != null then
      langValue
    else if starValue != null then
      starValue
    else
      globalValue;

  # The "*" entry (global defaults for feature toggles)
  starCfg = cfg."*";

  # All enabled languages (excluding "*")
  enabledLanguages = lib.pipe cfg [
    (lib.filterAttrs (name: _: name != "*"))
    (lib.filterAttrs (_: lang: lang.enable))
    builtins.attrValues
  ];

  # Resolve the grammar package for a language
  resolvePackage =
    lang:
    if lang.package != null then
      lang.package
    else
      let
        grammars = pkgs.vimPlugins.nvim-treesitter.builtGrammars;
      in
      grammars.${lang.languageName} or (throw ''
        Nixvim (treesitter): No grammar package found for language "${lang.languageName}".

        `pkgs.vimPlugins.nvim-treesitter.builtGrammars.${lang.languageName}` does not exist.

        Set `treesitter.languages.${lang.languageName}.package` explicitly to a grammar derivation,
        for example one built with `pkgs.tree-sitter.buildGrammar { ... }`.
      '');

  # Generate the content of an after/ftplugin/<filetype>.lua file
  mkFtpluginContent =
    lang:
    let
      effectiveHighlight =
        resolveFeature lang.highlight.enable starCfg.highlight.enable
          tsCfg.highlight.enable;
      effectiveFolds = resolveFeature lang.folds.enable starCfg.folds.enable tsCfg.folds.enable;
    in
    lib.concatStringsSep "\n" (
      lib.optional effectiveHighlight "vim.treesitter.start()"
      ++ lib.optionals effectiveFolds [
        "vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'"
        "vim.wo[0][0].foldmethod = 'expr'"
      ]
      # When a language is enabled but both features are off, the user is
      # explicitly opting out (e.g. for a filetype Neovim enables by default).
      # Emit vim.treesitter.stop(0) so the built-in ftplugin's start() is undone.
      ++ lib.optional (!effectiveHighlight && !effectiveFolds) "vim.treesitter.stop(0)"
    );

  # Determine the filetypes to generate ftplugin files for.
  # If `filetypes` is set, use those; otherwise use the language name.
  langFiletypes = lang: if lang.filetypes != [ ] then lang.filetypes else [ lang.languageName ];

  # Generate extraFiles entries for query overrides
  mkQueryFiles =
    lang:
    let
      langName = lang.languageName;
      mkQueryFile =
        queryType: queryCfg:
        let
          path = "queries/${langName}/${queryType}.scm";
        in
        lib.optionalAttrs (queryCfg.disable) {
          ${path}.text = "";
        }
        // lib.optionalAttrs (queryCfg.replace != null) {
          ${path}.text = queryCfg.replace;
        }
        // lib.optionalAttrs (queryCfg.extend != null) {
          ${path}.text = "; extends\n${queryCfg.extend}";
        };
    in
    lib.mkMerge [
      (mkQueryFile "highlights" lang.queries.highlights)
      (mkQueryFile "injections" lang.queries.injections)
      (mkQueryFile "folds" lang.queries.folds)
      (mkQueryFile "locals" lang.queries.locals)
    ];

  # Generate a vim.treesitter.language.register() call
  mkRegisterCall =
    lang:
    lib.optionalString (lang.filetypes != [ ]) ''
      vim.treesitter.language.register(${toLuaObject lang.languageName}, ${toLuaObject lang.filetypes})
    '';

  # Query option conflict assertions
  mkQueryAssertions =
    lang:
    let
      mkAssert =
        queryType: queryCfg:
        let
          setCount =
            (if queryCfg.replace != null then 1 else 0)
            + (if queryCfg.extend != null then 1 else 0)
            + (if queryCfg.disable then 1 else 0);
        in
        {
          assertion = setCount <= 1;
          message = ''
            Nixvim (treesitter): Language "${lang.languageName}" has multiple conflicting
            query options set for "${queryType}". At most one of `replace`, `extend`,
            or `disable` may be set.
          '';
        };
    in
    [
      (mkAssert "highlights" lang.queries.highlights)
      (mkAssert "injections" lang.queries.injections)
      (mkAssert "folds" lang.queries.folds)
      (mkAssert "locals" lang.queries.locals)
    ];
in
{
  options.treesitter.languages = lib.mkOption {
    type = types.submodule [
      {
        freeformType = types.attrsOf (mkLanguageType { });
      }
      {
        # "*" is a meta-entry for setting feature-toggle defaults.
        # It uses a stripped-down submodule without package, filetypes, etc.
        options."*" = lib.mkOption {
          description = ''
            Global defaults for tree-sitter feature toggles.

            Settings here override the top-level `treesitter.highlight.enable`
            and `treesitter.folds.enable` defaults, but are themselves overridden
            by per-language settings.

            Note: `enable` is not available on `"*"` because enabling a language
            requires specifying a grammar package. Use per-language `enable` instead.
          '';
          type = types.submodule ./global-language.nix;
          default = { };
        };
      }
    ];

    description = ''
      Per-language tree-sitter configuration.

      Each attribute name is a language/parser name. Set `enable = true` to
      install the grammar and generate the corresponding ftplugin.

      The special `"*"` entry sets default feature toggles inherited by all languages.

      Feature inheritance order (last wins):
      1. `treesitter.{highlight,folds}.enable` (global module defaults)
      2. `treesitter.languages."*".{highlight,folds}.enable`
      3. `treesitter.languages.<name>.{highlight,folds}.enable`
    '';
    default = { };
    example = lib.literalExpression ''
      {
        "*" = {
          highlight.enable = true;
          folds.enable = true;
        };
        rust.enable = true;
        python.enable = true;
        nu = {
          enable = true;
          package = treesitter-nu-grammar;
          filetypes = [ "nu" ];
        };
        markdown = {
          enable = true;
          queries.injections.extend = '''
            ; extra markdown injection rules
          ''';
        };
      }
    '';
  };

  config = lib.mkIf tsCfg.enable {
    # Grammar packages on runtimepath
    extraPlugins = map resolvePackage enabledLanguages;

    # ftplugin files for highlighting and folding
    extraFiles = lib.mkMerge (
      # after/ftplugin/<filetype>.lua files
      (builtins.concatMap (
        lang:
        map (ft: {
          "after/ftplugin/${ft}.lua".text = mkFtpluginContent lang;
        }) (langFiletypes lang)
      ) enabledLanguages)
      # Query override files
      ++ map mkQueryFiles enabledLanguages
    );

    # vim.treesitter.language.register() calls
    treesitter.luaConfig.content =
      let
        registerCalls = lib.concatStrings (map mkRegisterCall enabledLanguages);
      in
      lib.mkIf (registerCalls != "") registerCalls;

    # Assertions: query option conflicts
    assertions = builtins.concatMap mkQueryAssertions enabledLanguages;
  };
}
