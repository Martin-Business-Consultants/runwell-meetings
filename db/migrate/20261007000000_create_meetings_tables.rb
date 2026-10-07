# The plugin's own tables, prefixed with its key, pointing at core records (users, todos) by id.
class CreateMeetingsTables < ActiveRecord::Migration[8.1]
  def change
    create_table :meetings_meetings do |t|
      t.string :title, null: false
      t.datetime :starts_at, null: false
      t.text :agenda
      t.text :notes
      t.integer :created_by_id
      t.timestamps
    end
    add_index :meetings_meetings, :starts_at

    create_table :meetings_attendees do |t|
      t.integer :meeting_id, null: false
      t.integer :user_id, null: false
      t.timestamps
    end
    add_index :meetings_attendees, %i[meeting_id user_id], unique: true
    add_index :meetings_attendees, :user_id

    # What one person means to get done on one day: a piece of work, or a line of their own.
    create_table :meetings_priorities do |t|
      t.integer :user_id, null: false
      t.date :day, null: false
      t.integer :todo_id
      t.string :title
      t.integer :position, null: false, default: 0
      t.datetime :done_at
      t.integer :added_by_id
      t.timestamps
    end
    add_index :meetings_priorities, %i[user_id day position]
    add_index :meetings_priorities, %i[user_id day todo_id], unique: true
    add_index :meetings_priorities, :todo_id

    # One person's look back at one day.
    create_table :meetings_reports do |t|
      t.integer :user_id, null: false
      t.date :day, null: false
      t.text :went_well
      t.text :went_badly
      t.text :why
      t.text :next_up
      t.timestamps
    end
    add_index :meetings_reports, %i[user_id day], unique: true
    add_index :meetings_reports, :day
  end
end
