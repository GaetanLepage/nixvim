{
  example = {
    maps.byMode.normal."," = "<cmd>echo \"test\"<cr>";
  };

  custom = {
    maps.list = [
      {
        key = ",";
        action = "<cmd>echo \"test\"<cr>";
      }
      {
        mode = ["n" "s"];
        key = "<C-p>";
        action = "<cmd>echo \"test\"<cr>";
      }
    ];
  };
}
