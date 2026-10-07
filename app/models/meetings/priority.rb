module Meetings
  # What one person means to get done on one day: a piece of work (whose status says whether it
  # got done) or a line of their own, ticked off by hand.
  class Priority < ::ApplicationRecord
    self.table_name = "meetings_priorities"

    belongs_to :user, class_name: "::User"
    belongs_to :todo, class_name: "::Todo", optional: true
    belongs_to :added_by, class_name: "::User", optional: true

    validates :day, presence: true
    validates :title, presence: true, length: { maximum: 200 }, unless: :todo
    validates :todo_id, uniqueness: { scope: %i[user_id day], message: "is already a priority that day" }, allow_nil: true
    validate :for_a_person

    before_create { self.position = Priority.where(user_id: user_id, day: day).maximum(:position).to_i + 1 if position.zero? }

    scope :ordered, -> { order(:position, :id) }

    def self.for(user, day) = where(user: user, day: day).ordered

    def label = todo&.title || title
    def done? = todo ? todo.status == "done" : done_at.present?
    def status_label = todo ? todo.status.humanize : (done? ? "Done" : "Planned")

    # A line of one's own is ticked off here; work is marked done on the work itself.
    def mark!(done)
      raise ArgumentError, "Mark the work itself done: “#{todo.title}”." if todo

      update!(done_at: (done ? Time.current : nil))
    end

    private
      def for_a_person
        errors.add(:user, "must be a person, not an agent") if user&.agent?
      end
  end
end
