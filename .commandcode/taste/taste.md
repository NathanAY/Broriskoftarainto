# Taste

## Units & conventions
- Designer/UI-facing distance parameters (attack range, knockback, explosion/bounce/homing/orbit radii, weapon range) must be authored in **meters**, following the existing `movement_speed` stat which is already in meters/sec. Pixels are an internal boundary detail only (physics, `Vector2`, target selectors). Confidence: 0.8
- Pixel-unit values must be converted to/from meters through shared helper functions (e.g. `Stats.meters_to_px()` / `px_to_meters()`) rather than inline magic numbers scattered across call sites. Confidence: 0.75

## UI
- Tooltips that surface physical values should show explicit unit labels (e.g. `range: 1.33 m`, `knockback: 0.4 m/s`), not bare numbers. Confidence: 0.7

## Workflow
- Expects every conversion/refactor to ship with: a new test suite pinning the values, updates to existing tests that hardcoded the old units, and updates to the affected docs. Confidence: 0.7
- Runs the full gdunit suite after changes and compares `.gdunit.log` against a known baseline (warnings/errors/failures) rather than requiring a fully clean log. Confidence: 0.6
