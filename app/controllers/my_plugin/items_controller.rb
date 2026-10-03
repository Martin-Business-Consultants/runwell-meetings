module MyPlugin
  # Every action has an authorization rule and an agent tool, like the core's: an AI connected to
  # Runwell can do what the page does, with the caller's permissions.
  class ItemsController < ApplicationController
    allow_staff
    agent_tool :list_pinned_items, on: :index, title: "List pinned items", description: "Every client's pinned items, newest first."
    agent_tool :pin_item, on: :create, title: "Pin an item to a client",
      params: { item: { client_id: "integer!", body: "string!" } }, next_tools: %w[list_pinned_items]
    agent_tool :unpin_item, on: :destroy, title: "Remove a pinned item"

    def index
      @items = Item.ordered.includes(:client, :user)
    end

    def create
      item = Item.new(params.expect(item: %i[client_id body]).merge(user: Current.user))
      if item.save
        redirect_back fallback_location: main_app.client_path(item.client), notice: "Pinned to #{item.client.name}."
      else
        redirect_back fallback_location: my_plugin_items_path, alert: item.errors.full_messages.to_sentence
      end
    end

    def destroy
      item = Item.find(params[:id])
      return redirect_back(fallback_location: my_plugin_items_path, alert: "Only its author or a manager can remove it.") unless item.removable_by?(Current.user)

      item.destroy!
      redirect_back fallback_location: my_plugin_items_path, notice: "Removed."
    end
  end
end
