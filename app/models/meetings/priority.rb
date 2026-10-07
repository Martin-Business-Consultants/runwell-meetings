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

    # The person's own order for the day, kept by the core's positioning gem (as work's is on the
    # board): a new one goes last, and moving one shifts the rest.
    attribute :position, :integer, default: nil
    positioned on: %i[user_id day]

    scope :ordered, -> { order(:position, :id) }

    def self.for(user, day) = where(user: user, day: day).ordered

    def label = todo&.title || title
    def done? = todo ? todo.status == "done" : done_at.present?
    def status_label = todo ? todo.status.humanize : (done? ? "Done" : "Planned")

    def siblings = Priority.where(user_id: user_id, day: day).where.not(id: id)

    # Dragged to just before another of that day's (by id), or to the end without one.
    def move!(before: nil)
      neighbour = siblings.find_by(id: before) if before.present?
      update!(position: neighbour ? { before: neighbour.id } : :last)
    end

    # One place up or down, or to the top or bottom (the buttons, and agents).
    def shift!(direction)
      case direction.to_s
      when "up" then (above = siblings.where(position: ...position).order(position: :desc).first) && update!(position: { before: above.id })
      when "down" then (below = siblings.where(position: (position + 1)..).order(:position).first) && update!(position: { after: below.id })
      when "top" then update!(position: :first)
      when "bottom" then update!(position: :last)
      else raise ArgumentError, "Move it up, down, top or bottom."
      end
      self
    end

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
