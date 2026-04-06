# pi-traycer.nvim

**This app was entirely vibe-coded. Seriously, this line in the README is the only thing I wrote by hand. Enjoy :-]**

Traycer-like spec-driven development in Neovim using the [pi coding agent](https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent).

Create epics, generate structured implementation plans, track tasks — all without leaving your terminal.

## Requirements

- Neovim 0.10+
- [pi coding agent](https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent) installed and in PATH
- [snacks.nvim](https://github.com/folke/snacks.nvim)
- [edgy.nvim](https://github.com/folke/edgy.nvim)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (for tests)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "pbonh/pi-traycer.nvim",
  dependencies = {
    "folke/snacks.nvim",
    "folke/edgy.nvim",
    "nvim-lua/plenary.nvim",
  },
  opts = {},
}
```

### Pi Extension

Copy the `create_plan` extension to pi's extensions directory:

```bash
cp extensions/create-plan.ts ~/.pi/agent/extensions/
```

## Configuration

```lua
require("pi-traycer").setup({
  chat = { position = "right", size = 0.4 },
  plan = { position = "bottom", size = 0.3 },
  keymaps = {
    chat = "<leader>pc",
    epic = "<leader>pe",
    plan = "<leader>pp",
    send_selection = "<leader>ps",
    abort = "<leader>pa",
  },
  pi = {
    model = nil,
    thinking = nil,
    session_dir = nil,
  },
  notifications = {
    cost_on_completion = true,
    context_warning_pct = 80,
  },
})
```

Set any keymap to `false` to disable it.

## Commands

| Command | Description |
|---------|-------------|
| `:PiChat [message?]` | Toggle chat panel, optionally send message |
| `:PiEpic [title?]` | Create a new epic |
| `:PiPlan [epic-id?]` | Toggle plan panel |
| `:PiFileAdd [path?]` | Add file to context |
| `:PiBash <command>` | Run bash through pi |
| `:PiAbort` | Cancel current operation |
| `:PiStatus` | Show session stats |

## Keymaps

| Mapping | Action |
|---------|--------|
| `<leader>pc` | Toggle chat |
| `<leader>pe` | Create/focus epic |
| `<leader>pp` | Toggle plan panel |
| `<leader>ps` | Send selection to chat (visual mode) |
| `<leader>pa` | Abort |

**Plan panel buffer keymaps:**

| Key | Action |
|-----|--------|
| `t` | Toggle task status |
| `Enter` | Show task info |
| `d` | Show task details |
| `q` | Close panel |

## Running Tests

```bash
nvim --headless -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"
```

## Health Check

```vim
:checkhealth pi-traycer
```
