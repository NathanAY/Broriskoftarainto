# Context / Glossary

Lazy glossary of terms used across the project docs and code. Add terms as they come up.

- **event contract**: the checker seam (`src/Scripts/event_contract.gd`) that validates every
  `EventManager` emit/subscribe against a central schema registry. Violations (unknown event,
  non-Dictionary payload, missing required key, listener arity != 1) are rejected by the bus and
  reported with `push_error` in debug builds. All event payloads are a single Dictionary.
- **GDUnit4**: the canonical unit test framework for this project (see AGENTS.md); GUT is also
  installed side-by-side.