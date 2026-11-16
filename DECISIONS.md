# DECISIONS.md

Log of unspecified design choices made during prototype implementation, with one-line rationale.

## Step 0
- **Workspace folder name**: Kept existing repo directory `time-defense` (`project.godot` name `TimeDefense`) rather than renaming the folder to `time-tower-defense/`, using `res://` relative paths everywhere.
- **Renderer**: Switched `project.godot` from `Forward Plus` to `GL Compatibility` and set explicit `1280x720` viewport dimensions per Implementation Guide p. 3.
- **Balance data format**: Used `res://data/balance.gd` (`class_name Balance`) for typed constant access across GDScript modules with zero scene hard-coding.
- **Debug overlay default**: Opens visible on startup in Step 0 and toggles cleanly on `F1` via `_input` so UI focus never steals the key.
