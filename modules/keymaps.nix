{
  config,
  lib,
  ...
}:
with lib; let
  helpers = import ../lib/helpers.nix {inherit lib;};
  cfg = config.maps;

  # These are the configuration options that change the behavior of each mapping.
  mapConfigOptions = {
    silent =
      helpers.defaultNullOpts.mkBool false
      "Whether this mapping should be silent. Equivalent to adding <silent> to a map.";

    nowait =
      helpers.defaultNullOpts.mkBool false
      "Whether to wait for extra input on ambiguous mappings. Equivalent to adding <nowait> to a map.";

    script =
      helpers.defaultNullOpts.mkBool false
      "Equivalent to adding <script> to a map.";

    expr =
      helpers.defaultNullOpts.mkBool false
      "Means that the action is actually an expression. Equivalent to adding <expr> to a map.";

    unique =
      helpers.defaultNullOpts.mkBool false
      "Whether to fail if the map is already defined. Equivalent to adding <unique> to a map.";

    noremap =
      helpers.defaultNullOpts.mkBool true
      "Whether to use the 'noremap' variant of the command, ignoring any custom mappings on the defined action. It is highly advised to keep this on, which is the default.";

    remap =
      helpers.defaultNullOpts.mkBool false
      "Make the mapping recursive. Inverses \"noremap\"";

    desc =
      helpers.mkNullOrOption types.str
      "A textual description of this keybind, to be shown in which-key, if you have it.";
  };

  modes = {
    normal.short = "n";
    insert.short = "i";
    visual = {
      desc = "visual and select";
      short = "v";
    };
    visualOnly = {
      desc = "visual only";
      short = "x";
    };
    select.short = "s";
    terminal.short = "t";
    normalVisualOp = {
      desc = "normal, visual, select and operator-pending (same as plain 'map')";
      short = "";
    };
    operator.short = "o";
    lang = {
      desc = "normal, visual, select and operator-pending (same as plain 'map')";
      short = "l";
    };
    insertCommand = {
      desc = "insert and command-line";
      short = "!";
    };
    command.short = "c";
  };

  modeOptionNames = attrNames modes;

  mkMapOptionSubmodule = {
    defaultMode ? "",
    withKeyOpt ? true,
  }:
    with types;
      either
      str
      (types.submodule {
        options =
          (
            if withKeyOpt
            then {
              key = mkOption {
                type = types.str;
                description = "The key to map.";
                example = "<C-m>";
              };
            }
            else {}
          )
          // {
            mode = mkOption {
              type = let
                modeEnum =
                  enum
                  # ["" "n" "v" ...]
                  (
                    map
                    (
                      {short, ...}: short
                    )
                    (attrValues modes)
                  );
              in
                either modeEnum (listOf modeEnum);
              description = ''
                One or several modes.
                Use the short-names (`"n"`, `"v"`, ...).
                See `:h map-modes` to learn more.
              '';
              default = defaultMode;
              example = ["n" "v"];
            };

            action =
              if config.plugins.which-key.enable
              then helpers.mkNullOrOption types.str "The action to execute"
              else
                mkOption {
                  type = types.str;
                  description = "The action to execute.";
                };

            lua = mkOption {
              type = types.bool;
              description = ''
                If true, `action` is considered to be lua code.
                Thus, it will not be wrapped in `""`.
              '';
              default = false;
            };

            options = mapConfigOptions;
          };
      });
in {
  imports =
    map
    (
      mode:
        mkRenamedOptionModule
        ["maps" mode]
        ["maps" "byMode" mode]
    )
    # ["normal" "normalVisualOp" ...]
    modeOptionNames;

  options.maps = {
    allSilent = mkOption {
      type = types.bool;
      default = false;
      description = "Set this to `true` to make **all** of the nixvim key mappings silent.";
      example = true;
    };

    byMode =
      mapAttrs
      (
        modeName: modeProps: let
          desc = modeProps.desc or modeName;
        in
          mkOption {
            description = "Mappings for ${desc} mode";
            type = with types;
              attrsOf
              (
                either
                str
                (
                  mkMapOptionSubmodule
                  {
                    defaultMode = modeProps.short;
                    withKeyOpt = false;
                  }
                )
              );
            default = {};
          }
      )
      modes;

    list = mkOption {
      type = types.listOf (mkMapOptionSubmodule {});
      default = [];
      example = [
        {
          key = "<C-m>";
          action = "<cmd>make<CR>";
          options.silent = true;
        }
      ];
    };
  };

  config = let
    modeMapsAsList =
      flatten
      (
        mapAttrsToList
        (
          modeOptionName: modeProps:
            mapAttrsToList
            (
              key: action:
                (
                  if isString action
                  then {
                    mode = modeProps.short;
                    inherit action;
                    lua = false;
                    options = {};
                  }
                  else action
                )
                // {inherit key;}
            )
            cfg.byMode.${modeOptionName}
        )
        modes
      );

    mappings = let
      normalizeMapping = keyMapping:
        with keyMapping; {
          inherit
            mode
            key
            ;

          action =
            if lua
            then helpers.mkRaw action
            else action;

          options = let
            options' =
              keyMapping.options
              // (
                if cfg.allSilent
                then {silent = true;}
                else {}
              );
          in
            if options' == {}
            then helpers.emptyTable
            else options';
        };
    in
      map normalizeMapping
      (cfg.list ++ modeMapsAsList);
  in {
    extraConfigLua =
      optionalString (mappings != [])
      (
        if config.plugins.which-key.enable
        then ''
          -- Set up keybinds {{{
          do
            local __nixvim_binds = ${helpers.toLuaObject mappings}
            for i, map in ipairs(__nixvim_binds) do
              if not map.action then
                require("which-key").register({[map.key] = {name =  map.options.desc }})
              else
                vim.keymap.set(map.mode, map.key, map.action, map.options)
              end
            end
          end
          -- }}}
        ''
        else ''
          -- Set up keybinds {{{
          do
            local __nixvim_binds = ${helpers.toLuaObject mappings}
            for i, map in ipairs(__nixvim_binds) do
              vim.keymap.set(map.mode, map.key, map.action, map.options)
            end
          end
          -- }}}
        ''
      );
  };
}
