module MyPlugin
  # A short line pinned to a client. The table is the plugin's own (my_plugin_items); the client
  # and the person are core records, pointed at by id.
  class Item < ApplicationRecord
    self.table_name = "my_plugin_items"

    belongs_to :client
    belongs_to :user

    validates :body, presence: true, length: { maximum: 200 }

    scope :ordered, -> { order(created_at: :desc) }

    def removable_by?(person) = person == user || person.can?(:remove_pinned_items)
  end
end
