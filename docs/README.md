# Expedition Guild Idle - Codex Context Pack

This bundle is meant to be attached or referenced as context when prompting Codex or another coding agent.

Contents:
- `game_overview.md` - product/fantasy/core loop summary
- `current_milestone.md` - exact v0.1 implementation scope
- `technical_decisions.md` - stack and architecture constraints
- `coding_standards.md` - codebase rules for AI-generated code
- `content_schema.md` - data shapes and example JSON payloads
- `prompts/` - first 5 implementation prompts in build order

Recommended usage:
1. Attach the whole pack or paste the relevant files into context.
2. Keep `current_milestone.md` updated as scope changes.
3. Prompt Codex with one implementation prompt at a time.
4. Review, run, and commit after each prompt.

Core rule:
Build only the current milestone. Do not let the assistant invent extra systems.
