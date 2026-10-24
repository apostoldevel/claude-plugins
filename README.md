[![ru](https://img.shields.io/badge/lang-ru-green.svg)](README.ru-RU.md)

# claude-plugins

A [Claude Code plugin marketplace](https://docs.claude.com/en/docs/claude-code/plugin-marketplaces) by apostoldevel:
skills for the Apostol ecosystem — [libapostol](https://github.com/apostoldevel/libapostol) (C++20 transport) +
[db-platform](https://github.com/apostoldevel/db-platform) (PostgreSQL framework) — and for running development with a
named team of agents. One plugin per skill, each with its own version.

## Plugins

| Plugin | What it gives the agent | Version |
|---|---|---|
| [`apostol-project`](plugins/apostol-project/) | Working context for projects built on Apostol: three-layer architecture, ecosystem boundaries, DB patterns, access control, anti-patterns, verification, a reading route per role | [plugin.json](plugins/apostol-project/.claude-plugin/plugin.json) |
| [`apostol`](plugins/apostol/) | Developing the frameworks themselves — libapostol, db-platform, the shared C++ modules and processes: the submodule loop, the specification as the map, process model, plug-in contract, the contracts a platform change must keep. Never in one session with `apostol-project` | [plugin.json](plugins/apostol/.claude-plugin/plugin.json) |
| [`agent-team`](plugins/agent-team/) | Development as a visible named team of agents: roles, a git board, a working day on the owner's word, the owner's word by record; tested hook templates — write barrier, briefing, context guard, output filter | [plugin.json](plugins/agent-team/.claude-plugin/plugin.json) |

## Install

### Claude Code, one user

```
/plugin marketplace add apostoldevel/claude-plugins
/plugin install apostol-project@apostoldevel
/plugin install apostol@apostoldevel
/plugin install agent-team@apostoldevel
```

The same from a shell: `claude plugin marketplace add apostoldevel/claude-plugins`, then
`claude plugin install apostol-project@apostoldevel`. To update: `/plugin marketplace update apostoldevel`.

### Claude Code, a whole team

Commit to the project's `.claude/settings.json`. Whoever opens the project and trusts the folder is offered the
marketplace and the plugin:

```json
{
  "extraKnownMarketplaces": {
    "apostoldevel": {
      "source": { "source": "github", "repo": "apostoldevel/claude-plugins" }
    }
  },
  "enabledPlugins": {
    "apostol-project@apostoldevel": true
  }
}
```

### Other agents

The skills follow the open [Agent Skills](https://agentskills.io) format and install without Claude Code:

```bash
npx skills add apostoldevel/claude-plugins --skill apostol-project
```

### By hand

A skill is the directory `plugins/<plugin>/skills/<skill>/`. Link or copy it under the skill's name:

```bash
git clone https://github.com/apostoldevel/claude-plugins.git ~/src/apostoldevel-claude-plugins
ln -s ~/src/apostoldevel-claude-plugins/plugins/apostol-project/skills/apostol-project ~/.claude/skills/apostol-project
```

## Invocation

A plugin's skill is called by its own name, `/apostol-project`. If a personal or project skill of the same name is
also installed, the short name goes to that one and the plugin's copy becomes `/apostol-project:apostol-project`.
Keep one of the two.

## Layout

```
.claude-plugin/marketplace.json               the catalogue
plugins/<plugin>/.claude-plugin/plugin.json   name, version, licence
plugins/<plugin>/skills/<skill>/SKILL.md      the skill and its references
plugins/<plugin>/CHANGELOG.md                 history of the plugin
plugins/<plugin>/README.md                    what it does, how to use it
```

Each plugin carries its own [semver](https://semver.org) in its `plugin.json`, and the version changes with every
change: installed copies are updated by it. A skill keeps the name it is installed under everywhere: in
`npx skills` and in claude.ai skill names are global, with no plugin prefix.

Adding a plugin: the directory above, an entry in `marketplace.json`, then `claude plugin validate .`.

## Feedback

Issues and pull requests are welcome. A skill keeps only what holds on **every** project built on Apostol. A rule of
a single project belongs in that project's `CLAUDE.md` or wiki.

## License

[MIT](LICENSE), for every plugin unless its own directory says otherwise.
