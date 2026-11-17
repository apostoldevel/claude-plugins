# Changelog

Versions follow [semver](https://semver.org); the current one is in `.claude-plugin/plugin.json`. Dates are the
author's working days.

## 1.1.0 — 2026-11-17

Aligned with `/apostol-review` and with the rules for public repositories.

- **Added:** the library boundary — libapostol knows nothing of the modules built on it (no module code, no business
  rule, no db-platform objects; `src/dbplatform/` does not grow); "will others benefit" puts only a generic mechanism
  into the library; moving existing code out is its own task with every consumer listed, in the order new home →
  consumers → deprecated shim → removal. The submodule loop: commit by paths, push only on the owner's word as the
  project records it, the impersonal check before it. Searching with `git grep` or `/bin/grep` over explicit paths.
- **Corrected:** a deviation id goes to the task, never into an upstream commit; public code, tests, commits and
  READMEs say what the code does, in English, and name no project, task or specification id, attack path or incident;
  libapostol has tests since `909b599` (`APOSTOL_BUILD_TESTS=ON`, `ctest`); reviewing and auditing without changes
  routes to `/apostol-review`.

## 1.0.0 — 2026-10-24

First release in this marketplace. The skill existed before as a personal skill; this edition was checked line by line
against the code at libapostol `08ce5cc`, db-platform `eac160a` (1.2.35), go-platform `d6e47e7` and the shared module
pins, and against the Apostol Specification, Parts 0–III.

- **Corrected:** module configuration lives in one section `module.<Name>` (enable key `module.<Name>.enable`) — there
  is no `"modules"`/`"processes"` section; `ApostolModule` takes no constructor arguments, helper modules derive from
  `Module`; `PgPool::execute`, not `query`; none of the twelve shared modules uses `RoutedModule`; libapostol has no
  test suite; five feature flags, not three; db-platform has 28 modules; the README's benchmark figures.
- **Added:** the specification as the map (`where.py`, `drift.py`, `citecheck.py`; confidentiality of the deviation
  tables; neutrality of upstream); where the truth is (the project's submodule, not a local mirror); the process model
  and exact respawn backoff; the plug-in contract and the table of shared modules with their database interfaces;
  db-platform schemas, roles, life cycle, versions and patches; the extension and transport contracts a platform
  change must keep; the `/api/v2` road through GatewayAPI.
