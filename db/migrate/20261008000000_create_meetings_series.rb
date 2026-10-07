# A repeating meeting's rule, and which meetings came from it. Adds only, so it's safe on a live install.
class CreateMeetingsSeries < ActiveRecord::Migration[8.1]
  def change
    create_table :meetings_series do |t|
      t.string :title, null: false
      t.string :frequency, null: false
      t.string :weekdays
      t.string :time_of_day, null: false
      t.date :starts_on, null: false
      t.date :ends_on
      t.json :person_ids, null: false, default: []
      t.json :skipped_on, null: false, default: []
      t.text :agenda
      t.boolean :active, null: false, default: true
      t.integer :created_by_id
      t.timestamps
    end
    add_index :meetings_series, :active

    add_column :meetings_meetings, :series_id, :integer
    add_index :meetings_meetings, %i[series_id starts_at]
  end
end
