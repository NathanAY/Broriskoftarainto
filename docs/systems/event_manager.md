# Event Manager

Purpose
- Lightweight pub/sub event bus used to decouple systems.

Key scripts / scenes
- `Scripts/LocalEventManager.gd` (class_name `EventManager`)

Data flow
- Inputs: `subscribe(event_name, Callable)`, `unsubscribe(event_name, Callable)`, `emit_event(event_name, args)`.
- Processing: stores listeners in a Dictionary keyed by event name, iterates and calls each listener with provided args.
- Outputs: invokes listener callables; used to notify stat changes, item add/remove, damage events, etc.

Dependencies
- None directly; systems obtain a reference (often via `@onready` or parent-child wiring).

Known limitations / TODOs
- No protection against slow/failing listeners (no try/catch around calls).
- No priority ordering or one-shot listener mode (can be emulated by unsubscribe inside handler).
