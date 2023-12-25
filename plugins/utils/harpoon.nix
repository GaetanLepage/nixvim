{
  lib,
  helpers,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.plugins.harpoon;

  listOptions = {
    selectWithNil = helpers.defaultNullOpts.mkBool false ''
      If `true`, the list will call `select` even if the provided item is `nil`.
    '';

    encode = helpers.mkNullOrStrLuaFnOr (types.enum [false]) ''
      How to encode the list item to the harpoon file.
      If encode is false, then the list will not be saved to disk (think terminals).

      `fun(list_item: HarpoonListItem): string`
    '';

    decode = helpers.mkNullOrLuaFn ''
      How to decode the list item from the harpoon file.

      `fun(obj: string): any`
    '';

    display = helpers.mkNullOrLuaFn ''
      How to display the list item in the ui menu.

      `fun(list_item: HarpoonListItem): string`
    '';

    select = helpers.mkNullOrLuaFn ''
      The action taken when selecting a list item.
      Called from `list:select(idx, options)`.

      `fun(list_item?: HarpoonListItem, list: HarpoonList, options: any?): nil`
    '';

    equals = helpers.mkNullOrLuaFn ''
      How to compare two list items for equality.

      `fun(list_line_a: HarpoonListItem, list_line_b: HarpoonListItem): boolean`
    '';

    createListItem = helpers.mkNullOrLuaFn ''
      Called when `list:append()` or `list:prepend()` is called.
      Called with an item, which will be a string, when adding through the ui menu.

      `fun(item: any?): HarpoonListItem`
    '';

    bufLeave = helpers.mkNullOrLuaFn ''
      This function is called for every list on BufLeave.
      If you need custom behavior, this is the place.

      `fun(evt: any, list: HarpoonList): nil`
    '';

    vimLeavePre = helpers.mkNullOrLuaFn ''
      This function is called for every list on BufLeave.
      If you need custom behavior, this is the place.

      `fun(evt: any, list: HarpoonList): nil`
    '';

    getRootDir =
      helpers.defaultNullOpts.mkLuaFn
      ''
        function()
          return vim.loop.cwd()
        end
      ''
      ''
        Used for creating relative paths.

        `fun(): string`
      '';
  };
in {
  # TODO: those warnings have been introduced on 2023-12-27. Remove them in February 2024.
  imports = let
    basePluginPath = ["plugins" "harpoon"];
  in
    [
      (
        mkRenamedOptionModule
        (basePluginPath ++ ["saveOnToggle"])
        (basePluginPath ++ ["settings" "saveOnToggle"])
      )
      (
        mkRenamedOptionModule
        (basePluginPath ++ ["enableTelescope"])
        (basePluginPath ++ ["telescopeSupport" "enable"])
      )
    ]
    ++ (
      map
      (
        oldOptionPath:
          mkRemovedOptionModule
          (basePluginPath ++ oldOptionPath)
          ''
            `harpoon` has been rewritten and the nixvim project is now using the new version of the plugin.
            Please, refer to the nixvim documentation as well as the `harpoon2` README.
          ''
      )
      [
        ["keymaps" "gotoTerminal"]
        ["keymaps" "cmdToggleQuickMenu"]
        ["keymaps" "tmuxGotoTerminal"]
        ["saveOnChange"]
        ["enterOnSendcmd"]
        ["tmuxAutocloseWindows"]
        ["excludedFiletypes"]
        ["markBranch"]
        ["projects"]
        ["menu"]
      ]
    );

  options.plugins.harpoon =
    helpers.extraOptionsOptions
    // {
      enable = mkEnableOption "harpoon";

      package = helpers.mkPackageOption "harpoon" pkgs.vimPlugins.harpoon2;

      telescopeSupport = {
        enable = mkEnableOption "telescope integration";

        keyboardShortcut = helpers.mkNullOrOption types.str ''
          Keyboard shortcut to open the harpoon window.
        '';
      };

      # Global settings
      settings = {
        saveOnToggle = helpers.defaultNullOpts.mkBool false ''
          Any time the ui menu is closed then we will save the state back to the backing list, not
          to the fs.
        '';

        syncOnUiClose = helpers.defaultNullOpts.mkBool false ''
          Any time the ui menu is closed then the state of the list will be sync'd back to the fs.
        '';

        key =
          helpers.defaultNullOpts.mkLuaFn
          ''
            function()
              return vim.loop.cwd()
            end
          ''
          ''
            How the out list key is looked up.
            This can be useful when using worktrees and using git remote instead of file path.
          '';
      };

      default = listOptions;

      lists = mkOption {
        type = with types;
          attrsOf
          (
            submodule
            {options = listOptions;}
          );
        default = {};
        description = "Define the behavior for custom lists.";
      };

      keymapsSilent = mkOption {
        type = types.bool;
        description = "Whether harpoon keymaps should be silent.";
        default = false;
      };

      keymaps = {
        addFile = helpers.mkNullOrOption types.str ''
          Keymap for marking the current file.";
        '';

        toggleQuickMenu = helpers.mkNullOrOption types.str ''
          Keymap for toggling the quick menu.";
        '';

        navFile = helpers.mkNullOrOption (with types; attrsOf str) ''
          Keymaps for navigating to marks.

          Examples:
          navFile = {
            "1" = "<C-j>";
            "2" = "<C-k>";
            "3" = "<C-l>";
            "4" = "<C-m>";
          };
        '';

        navNext = helpers.mkNullOrOption types.str ''
          Keymap for navigating to next mark.";
        '';

        navPrev = helpers.mkNullOrOption types.str ''
          Keymap for navigating to previous mark.";
        '';
      };
    };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.telescopeSupport.enable -> config.plugins.telescope.enable;
        message = ''Nixvim: The harpoon telescope integration needs telescope to function as intended'';
      }
      {
        assertion = cfg.telescopeSupport.enable -> cfg.telescopeSupport.keyboardShortcut != null;
        message = ''
          Nixvim: You have enabled the telescope support for harpoon.
          Please define a keyboard shortcut using the `plugins.harpoon.telescopeSupport.keyboardShortcut` option.
        '';
      }
    ];

    extraPlugins = [cfg.package];

    extraConfigLua = let
      processListOptions = listOptions:
        with listOptions; {
          select_with_nil = selectWithNil;
          inherit
            encode
            decode
            display
            select
            equals
            ;
          create_list_item = createListItem;
          BufLeave = bufLeave;
          VimLeavePre = vimLeavePre;
          get_root_dir = getRootDir;
        };

      lists =
        mapAttrs
        (_: processListOptions)
        cfg.lists;

      setupOptions =
        {
          settings = with cfg.settings; {
            save_on_toggle = saveOnToggle;
            sync_on_ui_close = syncOnUiClose;
            key = helpers.mkRaw key;
          };

          default = processListOptions cfg.default;
        }
        // lists
        // cfg.extraOptions;

      telescopeConfig = ''
        local function toggle_telescope_harpoon(harpoon_files)
          local file_paths = {}
          for _, item in ipairs(harpoon_files.items) do
            table.insert(file_paths, item.value)
          end

          require("telescope.pickers").new({}, {
            prompt_title = "Harpoon",
            finder = require("telescope.finders").new_table({
                results = file_paths,
            }),
            previewer = conf.file_previewer({}),
            sorter = conf.generic_sorter({}),
          }):find()
        end
      '';
    in
      ''
        local harpoon = require('harpoon')
        harpoon:setup(${helpers.toLuaObject setupOptions})
      ''
      + (optionalString cfg.telescopeSupport.enable telescopeConfig);

    keymaps = let
      km = cfg.keymaps;

      simpleMappings = flatten (
        mapAttrsToList
        (
          optionName: luaFunc: let
            key = km.${optionName};
          in
            optional
            (key != null)
            {
              inherit key;
              action = "function() ${luaFunc} end";
            }
        )
        {
          addFile = "harpoon:list():append()";
          toggleQuickMenu = "harpoon.ui:toggle_quick_menu(harpoon:list())";
          navNext = "harpoon:list():next()";
          navPrev = "harpoon:list():prev()";
        }
      );

      navMappings =
        optionals
        (cfg.keymaps.navFile != null)
        (
          mapAttrsToList
          (id: key: {
            inherit key;
            action = "function() harpoon:list():select(${id}) end";
          })
          cfg.keymaps.navFile
        );

      telescopeMapping =
        optional cfg.telescopeSupport.enable
        {
          mode = "n";
          key = cfg.telescopeSupport.keyboardShortcut;
          action = ''
            function()
              toggle_telescope_harpoon(harpoon:list())
            end
          '';
          options.desc = "Open harpoon window";
        };

      allMappings = simpleMappings ++ navMappings ++ telescopeMapping;
    in
      helpers.keymaps.mkKeymaps
      {
        mode = "n";
        lua = true;
        options.silent = cfg.keymapsSilent;
      }
      allMappings;
  };
}
