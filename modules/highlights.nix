{
  lib,
  helpers,
  config,
  ...
}:
with lib; {
  options = {
    highlight = mkOption {
      type = types.attrsOf helpers.nixvimTypes.highlight;
      default = {};
      description = ''
        DEPRECATED: use `highlights` (with an `s`) instead.
        Define highlight groups.
      '';
      example = {
        Comment.fg = "#ff0000";
      };
      visible = false;
    };

    highlights = mkOption {
      type = types.attrsOf helpers.nixvimTypes.highlight;
      default = {};
      description = "Define highlight groups";
      example = {
        Comment.fg = "#ff0000";
      };
    };

    match = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = ''
        DEPRECATED: use `matchGroups` (with an `s`) instead.
        Define match groups
      '';
      example = {
        ExtraWhitespace = "\\s\\+$";
      };
      visible = false;
    };

    matchGroups = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Define match groups";
      example = {
        ExtraWhitespace = "\\s\\+$";
      };
    };
  };

  config = let
    highlights = config.highlight // config.highlights;
    matchGroups = config.match // config.matchGroups;
  in
    mkIf (highlights != {} || matchGroups != {}) {
      warnings =
        (optional (config.highlight != {}) ''
          Nixvim: `highlight`
        '')
        ++ (optional (config.match != {}) ''
          '');

      extraConfigLuaPost =
        (
          optionalString (highlights != {}) ''
            -- Highlight groups {{
            do
              local highlights = ${helpers.toLuaObject highlights}

              for k,v in pairs(highlights) do
                vim.api.nvim_set_hl(0, k, v)
              end
            end
            -- }}
          ''
        )
        + (optionalString (matchGroups != {}) ''
          -- Match groups {{
            do
              local match_groups = ${helpers.toLuaObject matchGroups}

              for k,v in pairs(match_groups) do
                vim.fn.matchadd(k, v)
              end
            end
            -- }}
        '');
    };
}
