[![en](https://img.shields.io/badge/lang-en-red.svg)](README.md)

# claude-plugins

[Маркетплейс плагинов Claude Code](https://docs.claude.com/en/docs/claude-code/plugin-marketplaces) от apostoldevel:
навыки для экосистемы Апостол — [libapostol](https://github.com/apostoldevel/libapostol) (транспорт на C++20) +
[db-platform](https://github.com/apostoldevel/db-platform) (фреймворк на PostgreSQL) — и для разработки командой
именованных агентов. Один навык — один плагин, у каждого своя версия.

## Плагины

| Плагин | Что получает агент | Версия |
|---|---|---|
| [`apostol-project`](plugins/apostol-project/) | Рабочий контекст для проектов на Апостоле: трёхуровневая модель, границы экосистемы, приёмы работы с БД, разграничение доступа, антипаттерны, проверка, маршрут чтения для каждой роли | [plugin.json](plugins/apostol-project/.claude-plugin/plugin.json) |
| [`agent-team`](plugins/agent-team/) | Разработка видимой командой именованных агентов: роли, доска в git, рабочий день по слову владельца, слово владельца записью; проверенные шаблоны хуков — барьер записи, брифинг, страж контекста, фильтр вывода | [plugin.json](plugins/agent-team/.claude-plugin/plugin.json) |

## Установка

### Claude Code, для себя

```
/plugin marketplace add apostoldevel/claude-plugins
/plugin install apostol-project@apostoldevel
/plugin install agent-team@apostoldevel
```

То же из командной строки: `claude plugin marketplace add apostoldevel/claude-plugins`, затем
`claude plugin install apostol-project@apostoldevel`. Обновление: `/plugin marketplace update apostoldevel`.

### Claude Code, для всей команды

Закоммитьте в `.claude/settings.json` проекта. Кто откроет проект и доверит каталог, тому будет предложено поставить
маркетплейс и плагин:

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

### Другие агенты

Навыки написаны в открытом формате [Agent Skills](https://agentskills.io) и ставятся без Claude Code:

```bash
npx skills add apostoldevel/claude-plugins --skill apostol-project
```

### Вручную

Навык — это каталог `plugins/<плагин>/skills/<навык>/`. Подключите его ссылкой или копией под именем навыка:

```bash
git clone https://github.com/apostoldevel/claude-plugins.git ~/src/apostoldevel-claude-plugins
ln -s ~/src/apostoldevel-claude-plugins/plugins/apostol-project/skills/apostol-project ~/.claude/skills/apostol-project
```

## Вызов

Навык из плагина вызывается своим именем: `/apostol-project`. Если рядом стоит личный или проектный навык с тем же
именем, короткое имя достаётся ему, а навык плагина вызывается как `/apostol-project:apostol-project`. Оставьте
что-то одно.

## Устройство

```
.claude-plugin/marketplace.json               каталог
plugins/<плагин>/.claude-plugin/plugin.json   имя, версия, лицензия
plugins/<плагин>/skills/<навык>/SKILL.md      навык и его справочники
plugins/<плагин>/CHANGELOG.md                 история плагина
plugins/<плагин>/README.md                    что делает, как пользоваться
```

У каждого плагина своя версия по [semver](https://semver.org) в `plugin.json`. Версия меняется с каждой правкой:
установленные копии обновляются по ней. Имя навыка одно везде: в `npx skills` и claude.ai имена навыков
глобальные, без префикса плагина.

Новый плагин: каталог по схеме выше, запись в `marketplace.json`, затем `claude plugin validate .`.

## Обратная связь

Issues и pull request'ы принимаются. В навыке остаётся только то, что верно для **любого** проекта на Апостоле.
Правило одного проекта — в его `CLAUDE.md` или вики.

## Лицензия

[MIT](LICENSE) — для всех плагинов, если в каталоге плагина не сказано иное.
