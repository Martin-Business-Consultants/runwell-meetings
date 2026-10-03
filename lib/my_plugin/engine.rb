module MyPlugin
  # A Runwell plugin: it owns its tables, points at core records by id, and reaches the core only
  # through the plugin contract (docs/plugin-contract.md in Runwell). Remove it and Runwell runs
  # as before.
  class Engine < ::Rails::Engine
    # Routes join the app's route set (as my_plugin_*), so the core layout's helpers work on the
    # plugin's pages.
    initializer "my_plugin.routes" do |app|
      app.routes.append do
        scope "my-plugin", module: "my_plugin", as: "my_plugin" do
          resources :items, only: %i[index create destroy]
        end
      end
    end

    # Associations on core models, through their load hooks. Never columns on core tables.
    initializer "my_plugin.models" do
      ActiveSupport.on_load(:runwell_client) { has_many :my_plugin_items, class_name: "MyPlugin::Item", dependent: :destroy }
    end

    # Every Event the core records reaches plugins from a job. Read who did it from the event;
    # there's no Current.user here.
    initializer "my_plugin.events" do
      ActiveSupport::Notifications.subscribe("event.runwell") do |*, payload|
        next unless Runwell::Plugins.enabled?(:my_plugin)

        event = payload[:event]
        Rails.logger.info("[my_plugin] #{event.kind} on #{event.subject_type} #{event.subject_id}") if event.kind == "client.created"
      end
    end

    config.to_prepare do
      Runwell::Plugins.register :my_plugin, name: "My plugin", version: MyPlugin::VERSION, author: "You",
        enabled_by_default: false, requires: ">= 2.12.0", homepage: "https://github.com/you/runwell-my-plugin",
        description: "Short items pinned to each client: an example of every part of a plugin."
      Runwell::Plugins.slot :client_panel, :my_plugin, "my_plugin/slots/client_panel"
      Runwell::Plugins.nav :my_plugin, "Pinned", -> { my_plugin_items_path }
      Runwell::Plugins.permission :my_plugin, :remove_pinned_items, name: "Remove anyone’s pinned items", roles: %w[owner manager]
      Runwell::Plugins.stylesheet :my_plugin, "my_plugin/items"
      Runwell::Plugins.nightly :my_plugin, -> { MyPlugin::Item.where(created_at: ...1.year.ago).delete_all }
    end
  end
end
