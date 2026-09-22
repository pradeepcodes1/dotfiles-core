-- Filetype icons, used by aerial, lualine, snacks, and the dashboard. Only
-- aerial declares it as a dependency; the others reach it through lazy.nvim's
-- module loader, which loads this on the first `require("nvim-web-devicons")`.
return { "nvim-tree/nvim-web-devicons", lazy = true }
