module Meetings
  # Everyone's week at once: a row per person, a column per weekday (Saturday and Sunday only when
  # someone has priorities then), each cell their priorities that day, done or not, and whether they
  # reported. Everyone active, or the people of one repeating meeting.
  class TeamWeek
    attr_reader :starts_on, :series

    def initialize(date, series: nil)
      @starts_on = date.beginning_of_week
      @series = series
    end

    def ends_on = starts_on + 6
    def range = starts_on..ends_on

    def people
      @people ||= (series ? series.people : ::User.active.people.ordered).to_a
    end

    def days
      @days ||= range.select { |date| date.on_weekday? || priorities.keys.any? { |(_, day)| day == date } }
    end

    def priorities
      @priorities ||= Priority.where(day: range, user_id: people.map(&:id)).ordered
        .includes(todo: [ :owner, { engagement: :client } ]).group_by { [ it.user_id, it.day ] }
    end

    def priorities_for(person, day) = priorities.fetch([ person.id, day ], [])
    def week_of(person) = priorities.select { |(user_id, _), _| user_id == person.id }.values.flatten

    def reports = @reports ||= Report.where(day: range, user_id: people.map(&:id)).index_by { [ it.user_id, it.day ] }
    def report_for(person, day) = reports[[ person.id, day ]]

    def done_count = priorities.values.flatten.count(&:done?)
    def total_count = priorities.values.sum(&:size)
    def this_week? = range.cover?(Date.current)
    def label = "#{I18n.l(starts_on, format: :long)} – #{I18n.l(ends_on, format: :long)}"
  end
end
