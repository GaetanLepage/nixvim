{
  empty = {
    plugins.cspell.enable = true;
  };

  defaults = {
    plugins.cspell = {
      enable = true;

      settings = {
        config_file_preferred_name = "cspell.json";
        cspell_config_dirs = [ ];
        find_json.__raw = ''
          function(directory)
              directory = vim.fs.normalize(directory)
              local files = vim.fs.find(CSPELL_CONFIG_FILES, { path = directory, upward = true, type = "file" })
              if files and files[1] then
                  return files[1]
              end

              return nil
          end
        '';
        read_config_synchronously = true;
        decode_json = "vim.json.decode";
        encode_json = "vim.json.encode";
        on_use_suggestion = null;
        on_add_to_json = null;
        on_add_to_dictionary = null;
      };
    };
  };

  example = {
    plugins.cspell = {
      enable = true;

      settings = {
      };
    };
  };
}
