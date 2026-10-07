module Meetings
  # One person in a meeting.
  class Attendee < ::ApplicationRecord
    self.table_name = "meetings_attendees"

    belongs_to :meeting, class_name: "Meetings::Meeting"
    belongs_to :user, class_name: "::User"

    validates :user_id, uniqueness: { scope: :meeting_id }
  end
end
