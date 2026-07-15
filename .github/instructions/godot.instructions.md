---
applyTo: "**/*.gd,**/*.tscn,**/*.tres,project.godot"
---

- Use Godot 4.7 syntax and APIs.
- Prefer typed GDScript and explicit return types.
- Keep node paths stable and update all references when changing scene structure.
- Treat `.tscn` and `.tres` files as merge-sensitive; avoid editor-generated churn outside the task.
- Never hand-edit `.uid` or `.import` metadata.
- For visual, physics, interaction, lighting, or audio changes, require an editor/runtime smoke test in addition to headless import validation.
