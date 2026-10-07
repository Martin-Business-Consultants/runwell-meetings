module Meetings
  # Everyone's day at once, to look at together: each person's priorities, done or not, and their
  # report. Everyone active, or the people in one meeting that day.
  class TeamDay
    attr_reader :date, :meeting

    def initialize(date, meeting: nil)
      @date = date
      @meeting = meeting
    end

    def people
      @people ||= (meeting ? meeting.people : ::User.active.people.ordered).to_a
    end

    def priorities
      @priorities ||= Priority.where(day: date, user_id: people.map(&:id)).ordered
        .includes(todo: [ :owner, { engagement: :client } ]).group_by(&:user_id)
    end

    def priorities_for(person) = priorities.fetch(person.id, [])
    def reports = @reports ||= Report.where(day: date, user_id: people.map(&:id)).index_by(&:user_id)
    def report_for(person) = reports[person.id]
    def meetings = @meetings ||= Meeting.on_day(date).order(:starts_at).to_a

    def done_count = priorities.values.flatten.count(&:done?)
    def total_count = priorities.values.sum(&:size)
    def today? = date == Date.current
    def label = I18n.l(date, format: :long)
  end
end
