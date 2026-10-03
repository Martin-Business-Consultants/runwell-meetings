# The plugin's own table, prefixed with its key. Safe on a live install: add, never rename or
# drop in the same release that stops using something.
class CreateMyPluginItems < ActiveRecord::Migration[8.1]
  def change
    create_table :my_plugin_items do |t|
      t.integer :client_id, null: false
      t.integer :user_id, null: false
      t.string :body, null: false
      t.timestamps
    end
    add_index :my_plugin_items, :client_id
  end
end
