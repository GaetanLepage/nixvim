{
  empty = {
    plugins.harpoon.enable = true;
  };

  example = {
    plugins.telescope.enable = true;

    plugins.harpoon = {
      enable = true;

      telescopeSupport = {
        enable = true;
        keyboardShortcut = "<C-p>";
      };

      settings = {
        saveOnToggle = false;
        syncOnUiClose = false;
        key = ''
          function()
            return vim.loop.cwd()
          end
        '';
      };

      default = {
        selectWithNil = false;
        encode = false;
        decode = null;
        display = null;
        select = null;
        equals = null;
        createListItem = null;
        bufLeave = null;
        vimLeavePre = null;
        getRootDir = ''
          function()
            return vim.loop.cwd()
          end
        '';
      };

      lists = {};

      keymapsSilent = true;
      keymaps = {
        addFile = "<leader>a";
        navFile = {
          "1" = "<C-j>";
          "2" = "<C-k>";
          "3" = "<C-l>";
          "4" = "<C-m>";
        };
        navNext = "<leader>b";
        navPrev = "<leader>c";
      };
    };
  };
}
