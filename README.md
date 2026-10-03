# Runwell plugin template

A working [Runwell](https://github.com/Martin-Business-Consultants/runwellv2) plugin to start
yours from. It pins short items to clients, and in doing so uses every common part of the plugin
contract:

| Part | Where |
| --- | --- |
| Manifest, slots, nav, permission, stylesheet, nightly task | `lib/my_plugin/engine.rb` |
| Routes joined to the app's | `lib/my_plugin/engine.rb` (`my_plugin.routes`) |
| An association on a core model | `lib/my_plugin/engine.rb` (`:runwell_client`) |
| Listening to the core's events | `lib/my_plugin/engine.rb` (`event.runwell`) |
| Its own table | `db/migrate`, `app/models/my_plugin/item.rb` |
| A tab on every client | `app/views/my_plugin/slots/_client_panel.html.erb` |
| A page, with agent tools and a JSON view for AI | `app/controllers/my_plugin/items_controller.rb`, `app/views/my_plugin/items` |
| CSS on Runwell's design tokens | `app/assets/stylesheets/my_plugin/items.css` |

## Start

1. Use this template on GitHub (or clone it) as `runwell-<your-plugin>`.
2. `bin/rename "Plant care"`: the key, module, tables and files take your name.
3. Set `author` and `homepage` in the gemspec and `lib/<key>/engine.rb`.
4. From a Runwell checkout beside it: `bin/rails "plugins:link[../runwell-plant-care]"`,
   `bin/rails db:migrate`, `bin/dev`, then switch it on in Settings › Plugins.

## Release

Bump `lib/<key>/version.rb`, commit, then `git tag v0.2.0 && git push --tags`. The workflow
publishes the release; installs see it in Settings › Plugins (or the next night) and update when
someone presses Update. Anyone installs it from Settings › Plugins by `owner/repo`.

## Read next

- [The plugin contract](https://github.com/Martin-Business-Consultants/runwellv2/blob/main/docs/plugin-contract.md):
  every extension point, its version and whether it's stable. Set `requires:` to the newest you use.
- [Plugins](https://github.com/Martin-Business-Consultants/runwellv2/blob/main/docs/plugins.md):
  installing, developing and releasing.
- [Theming](https://github.com/Martin-Business-Consultants/runwellv2/blob/main/docs/theming.md):
  the design tokens.
- `AGENTS.md` here: the rules for an AI working on the plugin.
