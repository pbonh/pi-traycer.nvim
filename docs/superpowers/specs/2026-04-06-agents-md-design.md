# AGENTS.md Design Spec

## Summary

Add an AGENTS.md file to pi-traycer.nvim that provides AI coding agents with full project context for contributing to the plugin. The file is a flat, linear Markdown reference document targeting beginner-level Neovim/Lua plugin developers.

## Audience

AI coding agents working **on** the pi-traycer.nvim codebase (contributors/maintainers), not end-users of the plugin.

## Approach

Flat reference document — a single linear Markdown file covering all sections in order, under 150 lines. No subdirectory modules.

## Sections

### 1. Project Overview & Traycer Mapping

A brief description of what pi-traycer.nvim is: a Neovim plugin that mirrors Traycer's spec-driven development workflow using the pi coding agent, integrated with snacks.nvim and edgy.nvim.

Stack: Neovim 0.10+, Lua, pi coding agent, snacks.nvim, edgy.nvim, plenary.nvim.

Traycer workflow mapping table:

| Traycer Concept | Plugin Module | Entry Point |
|---|---|---|
| PRD / Intent Capture | `plan.lua` — `:PiEpic` | `commands.lua` |
| Phases / Decomposition | `plan.lua` — task tree | `create_plan` extension |
| Plans / Tactical Changes | `plan.lua` — task dependencies | `.pi/plans/{id}.json` |
| Handoff / Implementation | `chat.lua` + `rpc.lua` | `:PiChat` |
| Verification / Guardrails | `context.lua` — editor state | `context.get_context()` |

### 2. Project Structure

Directory tree with one-liner descriptions for each key file:

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

### 3. Key Commands

```bash
# Run all tests
nvim --headless -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

# Run a single test file
nvim --headless -c "PlenaryBustedFile tests/rpc_spec.lua { minimal_init = 'tests/minimal_init.lua' }"

# Health check (inside Neovim)
:checkhealth pi-traycer
```

No build step — pure Lua plugin. The `extensions/create-plan.ts` TypeScript file is used by the pi agent directly, not built as part of the plugin.

### 4. RPC Protocol Reference

**Sending commands** (plugin to pi agent via stdin):
```json
{ "type": "prompt", "message": "..." }
{ "type": "bash", "command": "..." }
{ "type": "abort" }
```

**Receiving events** (pi agent to plugin via stdout, newline-delimited JSON):
- `agent_start` / `agent_end` — session lifecycle
- `message_update` — streaming text deltas
- `tool_execution_start` / `tool_execution_update` / `tool_execution_end` — tool calls
- `extension_ui_request` — interactive UI requests (select, confirm, input, editor)

**Process management:**
- Pi spawned as: `pi --mode rpc --session <file>` (optional `--model`, `--thinking`)
- Sessions stored at `.pi/sessions/`
- Auto-restart on crash (up to 3 attempts)
- Event dispatch via Lua subscription pattern: `rpc.on(event_type, handler)`

### 5. Code Style & Patterns

- **Module pattern:** Every file returns a table `M` with public functions as `M.function_name()` and local helpers as `local function name()`
- **Event-driven coupling:** Modules subscribe to RPC events rather than calling each other directly (e.g., `chat.subscribe(rpc)`, `plan.subscribe(rpc)`)
- **Config access:** Always via `require("pi-traycer.config").get()`, never by storing config in module-level variables
- **Buffer/window management:** Create splits with `vim.cmd`, manipulate buffers with `vim.api.nvim_buf_*` and `vim.api.nvim_win_*`
- **Snacks.nvim for UI:** Use `Snacks.picker()` and `Snacks.input()` for interactive elements, not custom floating windows
- **Data persistence:** Epics are JSON files at `.pi/plans/{id}.json` — use `vim.fn.json_encode`/`json_decode`
- **Test style:** Plenary busted — `describe`/`it` blocks, assertions via `assert.are.equal()`, `assert.is_true()`, etc.

### 6. Testing & Guardrails

**Testing rules:**
- Every new module needs a corresponding `tests/<module>_spec.lua` file
- Tests use `tests/minimal_init.lua` for a clean Neovim environment
- Tests should be self-contained — no dependency on a running pi agent
- Mock RPC events by calling dispatch/handler functions directly with test data

**Guardrails:**
- Don't break the RPC JSON line protocol. The `rpc.lua` parser expects one JSON object per line on stdout. Changing the delimiter, adding non-JSON output, or altering event type names will silently break communication with pi.
- Don't modify `extensions/create-plan.ts` without updating `plan.lua`'s parser. The plan module parses the `create_plan` tool's output by matching specific field names (`epic_title`, `tasks`, `id`, `title`, `description`, `dependencies`).
- Don't add Neovim plugin dependencies without adding them to the health check in `init.lua`.

## Constraints

- Single flat Markdown file, under 150 lines
- Beginner-friendly — explain Neovim plugin conventions and Lua patterns
- Light guardrails — only critical things to avoid
- Include RPC protocol reference inline
- Include Traycer workflow mapping table
