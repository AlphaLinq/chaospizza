# CLAUDE.md — Pizza Chaos

All project rules for AI agents live in **AGENTS.md** (shared with Codex). Follow it fully:

@AGENTS.md

## Claude-specific notes

- Talk to the developer in **Hungarian**; keep code, identifiers and code comments in English.
- If the `roblox-dev` plugin is installed, its skills (security, DataStores, strict typing, performance, UI, testing) apply on top of AGENTS.md. When they conflict, **AGENTS.md wins**.
- Use the Roblox Studio MCP (`Roblox_Studio` server) for verification as described in AGENTS.md section 7. Do not edit Rojo-managed scripts inside Studio.
- Use `gh` for issues/PRs when available: read the issue with `gh issue view <n>` before starting, and reference it in the PR (`Closes #<n>`).
- Before claiming something works, run `stylua --check src`, `selene src`, `rojo build -o build.rbxlx`, and a Studio playtest when the MCP is connected.
