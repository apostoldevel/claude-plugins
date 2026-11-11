<!-- Route of the /apostol-project skill: one role's reading order, opened from the routing table in SKILL.md. -->
# Route — Go / `/api/v2` behind GatewayAPI (where a project has one)

**Open when the task needs it:** [`frontend.md`](frontend.md) (tokens, cookies) · [`access-control.md`](access-control.md)
· [`facts-2026-09.md`](facts-2026-09.md) · [`design.md`](design.md) when a platform construct fights you.

**Skip unless asked:** [`entity.md`](entity.md), [`workflow.md`](workflow.md), [`conventions.md`](conventions.md).

**The specification:** Part III, Part II `GTW` and `DMN`.

## Rules of this layer

- **Access is decided in `api.*` and in the `rest.*` route.** `/api/v2` reaches `api.*` directly and skips every
  refusal the route makes: list them before you open an `api.*` function to a new road (`access-control.md`
  § Every door to an object, § `/api/v2` identity).
- A service (`client_credentials`) session is refused by `GuardSession` / `GuardAdministrator` by design.
