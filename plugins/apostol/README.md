[![ru](https://img.shields.io/badge/lang-ru-green.svg)](README.ru-RU.md)

# apostol

A Claude Code skill for **developing the Apostol frameworks themselves**: [libapostol](https://github.com/apostoldevel/libapostol)
(C++20 transport), [db-platform](https://github.com/apostoldevel/db-platform) (PostgreSQL framework) and the shared
C++ modules and processes (`module-*`, `process-*`, including GatewayAPI).

For work on a project **built on** Apostol — or for reading and auditing the frameworks without changing them — use
[`apostol-project`](../apostol-project/). Never load both in one session: they carry opposite defaults about what is
yours to change.

## What it gives the agent

- how framework work happens: patch in the project's submodule, verify with real code, push upstream, move the pin —
  and how a push can stay at home while reading like success;
- the Apostol Specification as the map (where it exists) and the code as the evidence;
- libapostol: build and flags, process model, lifecycle guarantees, the module plug-in contract, the shared modules
  and processes with their database interfaces;
- db-platform: 28 modules in load order, schemas and roles, install/update/patch life cycle, versions and patches,
  the extension and transport contracts a platform change must keep;
- the `/api/v2` road (GatewayAPI ↔ go-platform ↔ `daemon.begin/call/end`);
- v1 → v2 porting.

## Install

```
/plugin marketplace add apostoldevel/claude-plugins
/plugin install apostol@apostoldevel
```

If you kept an earlier personal copy in `~/.claude/skills/apostol/`, remove it after installing, so that only one
skill answers to the name.
