module Meetings
  # One person's day: their priorities, the meetings they're in, and how it went (their report).
  class Day
    attr_reader :user, :date
    attr_writer :report

    def self.parse(value)
      value.present? ? Date.iso8601(value.to_s) : Date.current
    rescue Date::Error
      Date.current
    end

    def initialize(user, date)
      @user = user.person
      @date = date
    end

    def priorities = @priorities ||= Priority.for(user, date).includes(todo: [ :owner, { engagement: :client } ]).to_a
    def report = defined?(@report) ? @report : (@report = Report.for(user, date))
    def meetings = @meetings ||= Meeting.on_day(date).with_person(user).order(:starts_at).to_a

    def done_count = priorities.count(&:done?)

    # The person's open work not already a priority today, soonest due first, to pick from.
    def open_work
      @open_work ||= ::Todo.open.where(owner: user).where.not(id: priorities.filter_map(&:todo_id))
        .includes(engagement: :client).order(Arel.sql("todos.due_on IS NULL, todos.due_on, todos.id")).limit(100).to_a
    end

    # Yesterday's priorities that weren't done, to carry over.
    def carry_over
      @carry_over ||= Priority.for(user, previous_workday).includes(:todo).reject(&:done?)
        .reject { |priority| priorities.any? { it.todo_id ? it.todo_id == priority.todo_id : it.title == priority.title } }
    end

    # Adds the unfinished ones from the previous workday to the end of this day's list.
    # (One insert, numbered after the last, rather than one placement each.)
    def carry_over!(by:)
      rows = carry_over
      return [] if rows.empty?

      last = Priority.where(user: user, day: date).maximum(:position).to_i
      now = Time.current
      Priority.insert_all!(rows.each_with_index.map do |priority, index|
        { user_id: user.id, day: date, todo_id: priority.todo_id, title: priority.title, added_by_id: by&.id,
          position: last + index + 1, created_at: now, updated_at: now }
      end)
      rows
    end

    def previous_workday
      day = date.prev_day
      day = day.prev_day while day.saturday? || day.sunday?
      day
    end

    def today? = date == Date.current
    def past? = date < Date.current
    def label = I18n.l(date, format: :long)
  end
end
