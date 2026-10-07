module Meetings
  # One person's look back at one day: what went well, what didn't, why, and what's next. Read
  # beside the day's priorities, done or not.
  class Report < ::ApplicationRecord
    self.table_name = "meetings_reports"

    FIELDS = {
      went_well: [ "What went well", "Wins, however small." ],
      went_badly: [ "What didn’t", "What slipped, stalled or went wrong." ],
      why: [ "Why", "What got in the way, or what made the difference." ],
      next_up: [ "Next", "What you’ll do about it, and what comes first tomorrow." ]
    }.freeze

    belongs_to :user, class_name: "::User"

    validates :day, presence: true
    validates :day, uniqueness: { scope: :user_id }
    validate :says_something

    before_validation :clear_empty_text

    scope :ordered, -> { order(:day) }

    def self.for(user, day) = find_by(user: user, day: day)

    private
      def clear_empty_text
        FIELDS.each_key { |field| self[field] = nil if ActionController::Base.helpers.strip_tags(self[field].to_s).squish.blank? }
      end

      def says_something
        errors.add(:base, "Say how the day went: at least one of #{FIELDS.values.map(&:first).map(&:downcase).to_sentence(last_word_connector: ", or ")}.") if FIELDS.keys.all? { self[it].blank? }
      end
  end
end
