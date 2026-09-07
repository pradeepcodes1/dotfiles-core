-- load Git status data used by the configured fetchers and file-list columns.
require("git"):setup()

-- Frame the file list and the tab, so the panes read as panels rather than
-- columns separated by whitespace.
require("full-border"):setup()

-- Show the same contextual Starship prompt in Yazi's header as in the shell.
require("starship"):setup()

-- Local plugins keep custom metadata rendering separate from third-party setup.
require("size-permissions"):setup()
require("line-count"):setup()
