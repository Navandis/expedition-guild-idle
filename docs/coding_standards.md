# Coding Standards

## Primary Goals
- Keep the codebase easy to understand.
- Keep each file focused on one responsibility.
- Make systems easy to test and easy to replace.
- Favor straightforward code over clever abstractions.

## File Responsibility Rules
Each script should answer one question only.

Examples:
- `ExpeditionGenerator.gd` generates expedition data.
- `ExpeditionManager.gd` tracks active expedition state and completion.
- `ReportController.gd` displays expedition results and handles reward collection UI.

Do not mix UI layout concerns with core simulation logic.

## Implementation Rules
- GDScript only.
- Do not introduce plugins or third-party dependencies for MVP.
- Do not redesign unrelated systems while implementing a task.
- Do not add extra features that were not requested.
- Keep public function names clear and literal.
- Prefer small helper functions when they improve readability.
- Add light comments only where behavior may be non-obvious.

## Simplicity Rules
- Prefer the simplest working implementation.
- Avoid abstract base classes unless already required.
- Avoid future-proofing for systems that do not exist yet.
- Avoid inheritance-heavy UI hierarchies.
- Avoid global mutable state outside of the agreed core managers.

## Data Rules
- Content should live in JSON where practical.
- Validate required fields when loading content.
- Use predictable keys and snake_case names.
- Keep content schema stable unless the milestone explicitly changes it.

## UI Rules
- Mobile-friendly layout.
- Clear hierarchy of information.
- Buttons and labels should use plain, readable text.
- It is acceptable for the MVP to be visually plain.

## Testing Rules
Ask for small sanity checks where the system is math-heavy or stateful.
Examples:
- expedition generation returns valid fields
- rewards stay inside expected ranges
- expedition completion cannot be collected twice
- save/load preserves active state

## Refactoring Rule
Do not refactor unless one of these is true:
- duplication is actively causing mistakes
- the current structure blocks the next milestone
- there is a reproducible bug caused by the current structure
