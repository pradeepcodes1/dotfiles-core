-- run a project's devcontainer.json and edit inside it, like VSCode's Dev Containers.
-- The plugin assumes the container runtime shares the host filesystem; under
-- colima (or Docker Desktop) on macOS it does not, so the config below routes
-- around the parts that break there.

-- Unpack the official release build matching the host version as root. The
-- default provider compiles Neovim from source as remoteUser, which takes
-- minutes and fails outright for a non-root user like "vscode" that can't
-- apt-get. The tarballs are glibc builds, so musl images (alpine) still need
-- their own provider.
local install_script = [[
set -e
case "$(uname -m)" in aarch64|arm64) arch=arm64 ;; *) arch=x86_64 ;; esac
url=https://github.com/neovim/neovim/releases/download/%s/nvim-linux-$arch.tar.gz
if command -v curl >/dev/null; then curl -fsSL "$url"; else wget -qO- "$url"; fi | tar -xz -C /opt
ln -sf /opt/nvim-linux-$arch/bin/nvim /usr/local/bin/nvim
]]

-- Run `docker exec -it ...` in its own tab. A clean quit drops the tab like
-- leaving VSCode's remote window; a failure stays open so its error is readable.
local function open_terminal(command)
	vim.cmd.tabnew()
	local buf = vim.api.nvim_get_current_buf()
	vim.fn.jobstart(command, {
		term = true,
		on_exit = function(_, code)
			if code == 0 then
				vim.schedule(function()
					if vim.api.nvim_buf_is_valid(buf) then
						vim.api.nvim_buf_delete(buf, { force = true })
					end
				end)
			end
		end,
	})
	-- The nested Neovim owns the whole tab, so give it back the keys the global
	-- terminal maps spend on split navigation. <C-Space> still leaves terminal mode.
	for _, key in ipairs({ "<C-h>", "<C-j>", "<C-k>", "<C-l>" }) do
		vim.keymap.set("t", key, key, { buffer = buf })
	end
	vim.cmd.startinsert()
end

return {
	-- GitHub mirror of codeberg.org/esensar/nvim-dev-container, synced upstream.
	"esensar/nvim-dev-container",
	enabled = not vim.g.nvim_preview,
	cmd = {
		"DevcontainerStart",
		"DevcontainerAttach",
		"DevcontainerExec",
		"DevcontainerStop",
		"DevcontainerStopAll",
		"DevcontainerRemoveAll",
		"DevcontainerLogs",
		"DevcontainerEditNearestConfig",
	},
	config = function()
		-- Every container gets a bind mount of a socket dir the plugin takes from
		-- tempname() when devcontainer.commands loads. That lands under
		-- /var/folders, which colima doesn't share with its VM, so `docker run`
		-- failed with "bind source path does not exist". Hand it a per-process
		-- dir under $HOME for just that require.
		local sockets_dir = vim.fn.stdpath("cache") .. "/devcontainer/" .. vim.uv.os_getpid()
		-- The plugin mkdirs it without "p", which throws if a reused pid left one.
		vim.fn.delete(sockets_dir, "rf")
		vim.fn.mkdir(vim.fs.dirname(sockets_dir), "p")
		local tempname = vim.fn.tempname
		vim.fn.tempname = function()
			return sockets_dir
		end
		local ok, err = pcall(require, "devcontainer.commands")
		vim.fn.tempname = tempname
		if not ok then
			error(err)
		end
		vim.api.nvim_create_autocmd("VimLeavePre", {
			desc = "Remove this session's devcontainer socket dir",
			callback = function()
				vim.fn.delete(sockets_dir, "rf")
			end,
		})

		require("devcontainer").setup({
			nvim_install_as_root = true,
			nvim_installation_commands_provider = function(_, version_string)
				return { { "sh", "-c", install_script:format(version_string) } }
			end,
			terminal_handler = open_terminal,
			-- colima's virtiofs share shows the project as root-owned inside the
			-- container, so git refused it as "dubious ownership" for remoteUser
			-- and `go build` failed on VCS stamping. Env config is command scope,
			-- which git honours for safe.directory.
			container_env = {
				GIT_CONFIG_COUNT = "1",
				GIT_CONFIG_KEY_0 = "safe.directory",
				GIT_CONFIG_VALUE_0 = "*",
			},
		})

		-- :DevcontainerStart only runs the container; the plugin adds Neovim on
		-- its own attach path, which the command below no longer takes. Add it
		-- on start instead. The plugin then commits the container to its cached
		-- image, so later starts already have it and skip this.
		local container = require("devcontainer.container")
		vim.api.nvim_create_autocmd("User", {
			pattern = "DevcontainerContainerStarted",
			desc = "Add Neovim to newly started devcontainers",
			callback = function(event)
				local id = event.data.container_id
				container.exec(id, {
					command = { "nvim", "--version" },
					on_success = function() end,
					on_fail = function()
						vim.notify("Adding Neovim to the devcontainer...")
						require("devcontainer.internal.nvim").add_neovim(id, {
							install_as_root = true,
							on_step = function() end,
							on_success = function()
								local function ready()
									vim.notify("Neovim is ready in the devcontainer: :DevcontainerAttach")
								end
								-- The plugin now runs `docker commit`, which pauses the container
								-- until it finishes; an attach in that window failed with
								-- "is paused", so only announce once the commit is done.
								if require("devcontainer.config").cache_images then
									vim.api.nvim_create_autocmd("User", {
										pattern = "DevcontainerContainerCommitted",
										once = true,
										callback = ready,
									})
								else
									ready()
								end
							end,
						})
					end,
				})
			end,
		})

		-- On Neovim 0.12 the plugin attaches with :connect to a Unix socket in
		-- that bind-mounted dir, but a socket can't be reached across the VM's
		-- virtiofs share (connection refused), and a UI without a "connect"
		-- event, like Neovide, just :detach-es. A table command takes the
		-- plugin's `docker exec -it` terminal path instead, which works in both.
		-- Arguments keep the plugin's meaning: [target] [command...].
		local commands = require("devcontainer.commands")
		vim.api.nvim_create_user_command("DevcontainerAttach", function(args)
			local target, command = "devcontainer", { "nvim" }
			if #args.fargs == 1 then
				command = { args.fargs[1] }
			elseif #args.fargs > 1 then
				target, command = args.fargs[1], vim.list_slice(args.fargs, 2)
			end
			if target ~= "devcontainer" then
				commands.attach_auto(target, command)
				return
			end
			require("devcontainer.config_file.parse").parse_nearest_devcontainer_config(
				vim.schedule_wrap(function(parse_err, data)
					-- Without workspaceFolder or workspaceMount the plugin mounts the
					-- project at /workspace but passes no --workdir, so the shell
					-- opened in the image's WORKDIR (/go in cli/cli's Go image).
					if not parse_err and data and not data.workspaceFolder and not data.workspaceMount then
						command = vim.list_extend({ "sh", "-c", 'cd /workspace && exec "$@"', "sh" }, command)
					end
					commands.attach_auto(target, command)
				end)
			)
		end, {
			nargs = "*",
			desc = "Open a command (default nvim) in the devcontainer in a terminal tab",
		})
	end,
}
