{
  example = {
    maps.normal."," = "<cmd>echo \"test\"<cr>";
  };

  custom = {
    maps.custom = {
      "," = "<cmd>echo \"test\"<cr>";
      "<C-p>" = {
        action = "<cmd>echo \"test\"<cr>";
        mode = ["n" "s"];
      };
    };
  };
}
