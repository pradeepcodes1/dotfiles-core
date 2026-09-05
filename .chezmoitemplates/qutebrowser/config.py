{{- $q := index .qutebrowser "linux" -}}
{{- if eq .chezmoi.os "darwin" }}{{ $q = index .qutebrowser "darwin" }}{{ end -}}
# qutebrowser bindings, mirroring the Neovim layer in
# chezmoi-core/dot_config/nvim/lua/core/keymaps.lua.
#
# Only bindings with a real analogue are carried over. Editor-only concepts --
# splits, folds, diagnostics, LSP symbols, projects -- have none here and are
# deliberately absent rather than bent into a weak parallel. What is missing and
# why is listed at the bottom of this file.
#
# Two facts drive the layout:
#
#   Space is entirely unbound in qutebrowser's defaults, so it is free to be the
#   leader that Neovim already uses.
#
#   Alt is not usable as a binding modifier on either platform this deploys to.
#   qutebrowser binds tab switching to <Alt-1>..<Alt-9> by default, and those
#   are dead both ways: a tiling compositor on Linux typically grabs Alt+digit
#   for workspaces before any client sees it, and on macOS Option+digit is a
#   text-input dead key that types symbols rather than reaching the browser.
#   Moving tab switching onto the leader is a portability requirement, not a
#   preference.

# GUI `:set` writes autoconfig.yml, which is loaded *before* this file and would
# silently win for anything not re-set below. Refusing it keeps this file the
# single source of truth; the cost is that `:set` no longer persists, which is
# the intended trade for a tracked config.
config.load_autoconfig(False)

# --- sizing ------------------------------------------------------------------
# Chromium-family browsers expose one device-scale knob for chrome and content
# together. qutebrowser splits them, so this is four settings rather than one:
#
#   fonts.default_size  every UI font. The statusbar, tab bar, completion,
#                       hints, prompts, downloads and messages are all declared
#                       as "default_size default_family", so this single value
#                       moves the whole chrome.
#   zoom.default        page content, layout and images.
#   fonts.web.size.*    the page's base font, in pixels.
#
# zoom.default multiplies the web sizes, so the two are not independent when
# tuning. The values live in .chezmoidata.toml under [qutebrowser.<os>] because
# they are display properties, not preferences: the Linux profile runs an
# unscaled 1440p panel at ~109 DPI and needs the compensation, while macOS
# already scales through the window server and would double up.
c.fonts.default_size = '{{ $q.chromeFontSize }}'
c.zoom.default = '{{ $q.zoom }}'
c.fonts.web.size.default = {{ $q.webFontSize }}
c.fonts.web.size.default_fixed = {{ $q.webFixedFontSize }}

# To retune, `:set fonts.default_size 13pt` takes effect immediately but will
# not persist -- load_autoconfig(False) above is what makes this file the only
# source of truth. Settle on a value live, then write it here.
#
# A session-wide alternative exists and is deliberately not used: QT_SCALE_FACTOR
# in dot_config/environment.d/ would scale qutebrowser exactly the way the
# Chromium flag did, but it applies to every Qt application in the session
# (qt6ct, pavucontrol, and anything else), which is a much larger blast radius
# than one browser's font settings.

# --- leaving modes -----------------------------------------------------------
# `jk` to leave insert, as in Neovim. Both keys are ordinary text here, so this
# costs a `bindings.key_timeout` wait after a literal `j` typed into a page's
# text field. That is the same trade Neovim makes in insert mode, where neither
# key is a motion.
config.bind('jk', 'mode-leave', mode='insert')

# Caret mode is the closest thing to visual mode, and Neovim leaves visual with
# `q` for the same reason it is free here.
config.bind('q', 'mode-leave', mode='caret')

# <Ctrl-C> leaves every mode that can be left -- the terminal and Vim reflex,
# and qutebrowser's default in none of them. In command mode the default is
# `completion-item-yank`, so Ctrl+C was not doing nothing, it was quietly
# copying the highlighted completion. <Ctrl-Shift-C> still yanks (with --sel),
# so that is a spelling change rather than a loss.
for _mode in ('command', 'prompt', 'hint', 'insert', 'caret'):
    config.bind('<Ctrl-C>', 'mode-leave', mode=_mode)

# --- completion menus --------------------------------------------------------
# blink.cmp walks the completion list with <C-j>/<C-k>, and plugins/blink.lua
# notes that <C-k> has to be reclaimed from show_signature to get it. The same
# reclaim is needed here: <Ctrl-K> is `rl-kill-line` in command and prompt mode.
# That kill is the one real casualty. <Ctrl-U> still discards to the start of
# the line, which covers the common case, and it cannot simply move to Alt+K,
# for the same reason the tab bindings avoid Alt (see the header).
config.bind('<Ctrl-J>', 'completion-item-focus next', mode='command')
config.bind('<Ctrl-K>', 'completion-item-focus prev', mode='command')
config.bind('<Ctrl-J>', 'prompt-item-focus next', mode='prompt')
config.bind('<Ctrl-K>', 'prompt-item-focus prev', mode='prompt')

# --- q, taken back from macro recording --------------------------------------
# Neovim maps `q` to :nohlsearch precisely to stop bare `q` starting a macro.
# qutebrowser's default is `macro-record`, so the same rebinding does the same
# two jobs: clear the search highlight, and make a stray `q` harmless.
config.bind('q', 'clear-keychain ;; search')

# --- jumping to a target -----------------------------------------------------
# flash.nvim takes `s`/`S` to label a jump target instead of counting a motion.
# Hint mode is the same idea, so `s` gets it here too. `f`/`F` stay bound to
# their qutebrowser defaults; this adds a spelling rather than removing one.
config.bind('s', 'hint')
config.bind('S', 'hint all tab')

# --- history, as the jumplist ------------------------------------------------
# Neovim leaves <C-o>/<C-i> at their defaults, walking back and forward through
# the jumplist. Session history is the browser's jumplist, and both keys are
# unbound in qutebrowser, so this costs nothing. `H`/`L` keep doing the same job
# alongside them.
#
# Worth noting why this is safe here and would not be in a terminal: Ctrl+I and
# Tab are the same byte (0x09) on a TTY, which is why Vim cannot tell them
# apart. Qt delivers them as distinct key events -- qutebrowser parses <Ctrl-I>
# to <Ctrl+i> and <Tab> to <Tab> -- so binding one does not shadow the other.
config.bind('<Ctrl-O>', 'back')
config.bind('<Ctrl-I>', 'forward')

# --- scroll speed ------------------------------------------------------------
# `scroll down` is implemented as one synthetic Down keypress, which is a single
# line and reads as sluggish on a 1440p page. `scroll` documents the intended
# fix in its own docstring: drive it through `cmd-run-with-count` rather than
# binding a fixed pixel distance.
#
# The multiplier is the right lever precisely because it stays a line count.
# `scroll-px 0 120` would hard-code a distance that stops matching the text the
# moment zoom.default or fonts.web.size.default changes above; three lines stays
# three lines. Raise or lower the 3 to taste -- it is the only number here.
config.bind('j', 'cmd-run-with-count 3 scroll down')
config.bind('k', 'cmd-run-with-count 3 scroll up')

# Half- and full-page scrolling has to be rebound for the same reason, and this
# is a correctness fix rather than a preference. qutebrowser has two families of
# scroll command and they are not interchangeable:
#
#   scroll-page, scroll-px   run_js_async -> window.scrollBy / scroll.delta_page
#   scroll <direction>       _repeated_key_press(Key_Down / Key_PageDown)
#
# The JS family scrolls the *document*. When a page puts its content in a nested
# scrollable element -- which is most SPAs -- the document never scrolls and
# those commands silently do nothing, while the key-press family reaches the
# focused element and works. Measured on a nested-container fixture: after
# `scroll-page 0 0.5` the container's scrollTop was 0; after 20 `scroll down`
# it was 800. qutebrowser binds <Ctrl-U>/<Ctrl-D>/<Ctrl-B>/<Ctrl-F> to the JS
# family by default, so they appear broken on exactly the sites j/k still work.
#
# page-down/page-up are key presses too, so <C-f>/<C-b> stay exact. There is no
# key-press half-page, so <C-d>/<C-u> approximate it: the same fixture measured
# 800px over 20 presses, i.e. 40px per press, making 16 presses ~640px -- about
# half of this window. Adjust if the window height changes a lot.
config.bind('<Ctrl-D>', 'cmd-run-with-count 16 scroll down')
config.bind('<Ctrl-U>', 'cmd-run-with-count 16 scroll up')
config.bind('<Ctrl-F>', 'scroll page-down')
config.bind('<Ctrl-B>', 'scroll page-up')

# `scrolling.smooth` is left off, as qutebrowser ships it. Larger jumps are the
# case where it helps most, so it is worth trying with `:set scrolling.smooth
# true`, but it is disabled by default for real reasons (jank on heavy pages)
# and that is not a default to flip blind.

# --- tabs, mirroring the barbar buffer layer ---------------------------------
# <leader>1..9 jumps to buffer N, <leader>0 pins, and the shifted digit row
# moves the buffer to position N. Tabs map onto that one-to-one.
for i in range(1, 10):
    config.bind('<Space>{}'.format(i), 'tab-focus {}'.format(i))
config.bind('<Space>0', 'tab-pin')

for i, key in enumerate(['!', '@', '#', '$', '%', '^', '&', '*', '('], start=1):
    config.bind('<Space>{}'.format(key), 'tab-move {}'.format(i))

# <leader>q closes the buffer, <leader>Q quits. Same split here.
config.bind('<Space>q', 'tab-close')
config.bind('<Space>Q', 'quit')

# <leader>` is the buffer picker in Neovim; this is the tab picker.
config.bind('<Space>`', 'cmd-set-text -sr :tab-focus')

# --- finding things ----------------------------------------------------------
# <leader>ff finds files. The `:open` completion draws on history, bookmarks and
# quickmarks, so it is the same "type a fragment, pick a target" gesture.
#
# All three open in a new tab (-t) rather than the current one, because that is
# what makes them the analogue they claim to be: <leader>ff in Neovim opens the
# file in a new buffer, it does not discard the buffer you were in. Without -t
# these would replace the page you are on, which is `:open`'s default and the
# wrong half of the parallel.
config.bind('<Space>ff', 'cmd-set-text -s :open -t')
config.bind('<Space>fr', 'open -t qute://history')
config.bind('<Space>fb', 'cmd-set-text -s :quickmark-load -t')

# <leader>/ searches within the current buffer.
config.bind('<Space>/', 'cmd-set-text /')

# --- search engines ----------------------------------------------------------
# The equivalent of other browsers' keyword searches. Prefix a query in `:open`
# with a shortcut -- `gh qutebrowser`, `aw systemd` -- and the rest is
# substituted into the URL. `{}` quotes everything except slashes, which is the
# right choice for every engine here; `{quoted}` and `{unquoted}` exist for the
# rare engine that needs different escaping.
#
# DEFAULT is required by the setting, and is what `url.auto_search` falls back
# to when the address bar gets something that is not a URL. It stays on
# DuckDuckGo, qutebrowser's own default.
#
# These also feed the `searchengines` category of the `:open` completion, so
# they are discoverable by typing rather than needing to be memorised -- which
# matters more here than elsewhere, since qutebrowser has no live suggestions
# from the search provider and never contacts one as you type.
c.url.searchengines = {
    'DEFAULT': 'https://duckduckgo.com/?q={}',
    'g': 'https://www.google.com/search?q={}',
    'yt': 'https://www.youtube.com/results?search_query={}',
    'gh': 'https://github.com/search?q={}',
    # Maps takes the query as a path segment, so it wants {unquoted}:
    # with the default {} a search like 'cafe near me/park' would have
    # its slash left bare and split the path. {unquoted} is wrong here
    # for the opposite reason, so {quoted} escapes the lot.
    'gm': 'https://www.google.com/maps/search/{quoted}',
    # Arch-specific, since this is the profile's machine: the wiki, the
    # official repositories and the AUR are the three places a package
    # question actually gets answered.
    'aw': 'https://wiki.archlinux.org/index.php?search={}',
    'ap': 'https://archlinux.org/packages/?q={}',
    'aur': 'https://aur.archlinux.org/packages?K={}',
    'kd': 'https://www.kernel.org/doc/html/latest/search.html?q={}',
}

# --- jump list ---------------------------------------------------------------
# Sites reached often enough that typing them is friction. These have no Neovim
# counterpart -- they are bookmarks on the leader, not a mirror of anything --
# so they are grouped separately rather than pretending otherwise.
#
# All open in a new tab, matching the <Space>f* group above: a jump should not
# discard the page you were reading. Drop the -t on any of them to replace the
# current tab instead.
#
# Single letters under <Space> are free: the only other leader chains are f
# (finding), the digit rows (tabs), q/Q, ` and /, none of which start with these
# letters, so none of these introduce a keychain wait.
config.bind('<Space>y', 'open -t https://www.youtube.com/')
config.bind('<Space>d', 'open -t https://duckduckgo.com/')
config.bind('<Space>g', 'open -t https://www.google.com/')
config.bind('<Space>m', 'open -t https://mail.google.com/mail/u/0/#inbox')
config.bind('<Space>i', 'open -t https://github.com/')

# --- carried over untouched --------------------------------------------------
# These already agree with the Neovim layer and are left at their qutebrowser
# defaults rather than restated:
#
#   <Ctrl-e> <Ctrl-y>
#       unbound in qutebrowser, and left that way. neoscroll gives them 10% of
#       the window, which at 40px per line is ~3 lines -- indistinguishable from
#       the j/k above, so binding them would add a duplicate rather than a
#       distinct motion. (<Ctrl-u>/<Ctrl-d>/<Ctrl-b>/<Ctrl-f> are *not* in this
#       list: they are rebound above, see the scroll speed section.)
#   gg  G       top and bottom
#   /  n  N     search and repeat
#   i  v        enter insert and caret mode
#   u           undo, as in Neovim's undo
#   ga  <C-T>   new blank tab; O opens a URL in one, gC clones the current tab.
#               `t` is unbound in qutebrowser 3.7 and left that way -- Neovim
#               has no `t` for a new buffer, so binding it would be invention,
#               not a mirror. <Space>ff is the leader-side spelling.
#   H  L        back and forward, alongside the <C-o>/<C-i> pair above
#   yy  pp      yank and put
#   <Tab> <S-Tab>  completion navigation, alongside the <C-j>/<C-k> pair above
#
# --- deliberately not bound --------------------------------------------------
# Neovim bindings with no counterpart here, listed so their absence reads as a
# decision rather than an oversight:
#
#   <C-h/j/k/l>, <leader>|, <leader>\, <leader>x, <leader>w<arrows>
#       splits and split resizing; qutebrowser has no window splits
#   zz                          fold toggle; no folds
#   ?, ]d, [d, <leader>l*       diagnostics and LSP; no language server
#   <leader>s, <leader>f{s,S}   symbol pickers; no symbols
#   <leader>p, <leader>e        projects and the file explorer
#   <leader>g*, <leader>df      diffview
#   ]t, [t, <leader>ft          todo-comments
#
# `?` is left as qutebrowser's reverse search. Neovim only rebinds it because a
# diagnostic float needed a home, and nothing here does.

# --- local overrides ---------------------------------------------------------
# The seam this file offers to an overlay or a single machine, mirroring the
# `globinclude local.d/*.conf` at the end of the portable kitty config -- and,
# like that glob, deliberately the *last* thing this file does. Every .py in
# config.d/ is sourced, in sorted order, after every setting above, so an
# overlay can drop in a generated colour scheme, add a host-only tweak, or
# replace something this file assigns, without either source having to own this
# file.
#
# Sourcing last is the whole point, and was not always the case. This block used
# to sit near the top, ahead of the settings, which made the seam write-only for
# anything core also declared: fonts.default_size, zoom.default, fonts.web.size.*,
# url.searchengines and every binding above were reassigned afterwards, so an
# overlay's version of any of them was silently ineffective rather than an
# error, and only settings core never touched survived. Moving it here is what
# makes the comparison to the kitty seam true rather than aspirational -- an
# overlay now wins a conflict, the same way an overlay `map` wins a chord there.
#
# The is_dir check and the sorted glob are both load-bearing: config.source()
# on a missing file raises, and a raise here aborts the whole config. Running
# last also bounds that blast radius -- core's own settings and bindings have
# already applied by the time an overlay gets the chance to fail. An absent
# config.d/ is the normal state on a machine with no overlay.
_local_dir = config.configdir / 'config.d'
if _local_dir.is_dir():
    for _local in sorted(_local_dir.glob('*.py')):
        config.source(str(_local.relative_to(config.configdir)))
