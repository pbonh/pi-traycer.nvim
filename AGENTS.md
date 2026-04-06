# AGENTS.md — pi-traycer.nvim

## Project Overview

pi-traycer.nvim is a Neovim plugin that brings Traycer-style spec-driven development into the terminal. It uses the **pi coding agent** for AI-powered chat and code generation, **snacks.nvim** for UI components (pickers, inputs), and **edgy.nvim** for panel docking.

**Stack:** Neovim 0.10+, Lua, pi coding agent, snacks.nvim, edgy.nvim, plenary.nvim

### Traycer Workflow Mapping

This plugin mirrors Traycer's five-step development workflow:

| Traycer Concept | Plugin Module | Entry Point |
|---|---|---|
| PRD / Intent Capture | `plan.lua` — `:PiEpic` | `commands.lua` |
| Phases / Decomposition | `plan.lua` — task tree | `create_plan` extension |
| Plans / Tactical Changes | `plan.lua` — task dependencies | `.pi/plans/{id}.json` |
| Handoff / Implementation | `chat.lua` + `rpc.lua` | `:PiChat` |
| Verification / Guardrails | `context.lua` — editor state | `context.get_context()` |

## Project Structure

```
pi-traycer.nvim/
├── plugin/pi-traycer.lua          # Entry point — calls setup()
├── lua/pi-traycer/
│   ├── init.lua                   # setup() and health check
│   ├── config.lua                 # Default config, merging user opts
│   ├── state.lua                  # In-memory session state (epic ID, tokens)
│   ├── commands.lua               # All :Pi* command definitions
│   ├── rpc.lua                    # Bidirectional RPC with pi agent
│   ├── chat.lua                   # Chat panel UI and message formatting
│   ├── plan.lua                   # Epic/task CRUD, plan panel UI
│   ├── context.lua                # Gathers editor context for prompts
│   ├── extension_ui.lua           # Handles pi extension UI requests
│   └── keymaps.lua                # Keymap registration
├── extensions/create-plan.ts      # Pi extension for structured plans
├── tests/                         # Plenary busted tests
│   ├── minimal_init.lua           # Test harness setup
│   ├── chat_spec.lua
│   ├── plan_spec.lua
│   ├── rpc_spec.lua
│   ├── config_spec.lua
│   ├── context_spec.lua
│   ├── state_spec.lua
│   └── extension_ui_spec.lua
```

### Neovim Plugin Conventions

- `plugin/` contains the entry point Lua file. Neovim sources this automatically when the plugin is on `runtimepath`.
- `lua/pi-traycer/` contains all module code. Modules are loaded with `require("pi-traycer.module_name")`.
- `tests/` contains Plenary busted test files. Each test file corresponds to a module.

## Key Commands

```bash
# Run all tests
nvim --headless -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

# Run a single test file
nvim --headless -c "PlenaryBustedFile tests/rpc_spec.lua { minimal_init = 'tests/minimal_init.lua' }"

# Health check (inside Neovim)
:checkhealth pi-traycer
```

No build step — this is a pure Lua plugin. The `extensions/create-plan.ts` TypeScript file is consumed by the pi agent directly, not built as part of the plugin.

## RPC Protocol

The plugin communicates with the pi coding agent over stdin/stdout using newline-delimited JSON.

### Sending Commands (plugin to pi via stdin)

```json
{ "type": "prompt", "message": "..." }
{ "type": "bash", "command": "..." }
{ "type": "abort" }
```

### Receiving Events (pi to plugin via stdout)

Each line is one JSON object. Event types:

- `agent_start` / `agent_end` — session lifecycle
- `message_update` — streaming text delta from the agent
- `tool_execution_start` / `tool_execution_update` / `tool_execution_end` — tool call lifecycle
- `extension_ui_request` — interactive UI request (select, confirm, input, editor)

### Process Management

- Pi is spawned as: `pi --mode rpc --session <file>` (optional `--model`, `--thinking` flags)
- Session logs are stored at `.pi/sessions/`
- The plugin auto-restarts pi on crash (up to 3 attempts)
- Modules subscribe to events via: `rpc.on(event_type, handler)` / `rpc.off(event_type, handler)`

## Code Style

- **Module pattern:** Every file returns a local table `M`. Public functions are `M.function_name()`. Local helpers are `local function name()`. This is the standard Neovim plugin convention.
- **Event-driven coupling:** Modules subscribe to RPC events rather than calling each other. Example: `chat.subscribe(rpc)` registers chat's event handlers with the RPC module.
- **Config access:** Always read config via `require("pi-traycer.config").get()`. Do not cache config in module-level variables.
- **Buffer/window management:** Create splits with `vim.cmd("vsplit")` or `vim.cmd("split")`. Manipulate buffers with `vim.api.nvim_buf_*` and windows with `vim.api.nvim_win_*`.
- **UI components:** Use `Snacks.picker()` and `Snacks.input()` for interactive elements. Do not create custom floating windows.
- **Data persistence:** Epics are stored as JSON at `.pi/plans/{id}.json`. Encode/decode with `vim.fn.json_encode()` / `vim.fn.json_decode()`.
- **Tests:** Plenary busted framework — `describe`/`it` blocks with `assert.are.equal()`, `assert.is_true()`, etc.

## Testing & Guardrails

### Testing Rules

- Every new module needs a `tests/<module>_spec.lua` file
- Tests use `tests/minimal_init.lua` for a minimal Neovim environment with no user config
- Tests must be self-contained — no dependency on a running pi agent process
- Mock RPC events by calling handler functions directly with test data

### Guardrails

- **Do not break the RPC JSON line protocol.** `rpc.lua` parses one JSON object per stdout line. Adding non-JSON output, changing delimiters, or renaming event types will silently break pi communication.
- **Do not modify `extensions/create-plan.ts` without updating `plan.lua`.** The plan module matches specific field names from the `create_plan` tool output: `epic_title`, `tasks`, `id`, `title`, `description`, `dependencies`.
- **Do not add plugin dependencies without updating the health check** in `init.lua` (`M.health()`).
