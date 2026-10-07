module Meetings
  # A person's priorities for a day: added from their own page or in a meeting, by anyone on the
  # team, and ticked off when they're lines of their own (work is marked done on the work).
  class PrioritiesController < ApplicationController
    allow_staff
    agent_tool :add_priority, on: :create, title: "Add a priority to someone's day",
      description: "todo_id: a piece of work, or title: a line of their own. user_id: whose (you, if left out; the work's owner if it has one and you name nobody). day: YYYY-MM-DD, today if left out.",
      params: { priority: { user_id: "integer", day: "date", todo_id: "integer", title: "string" } }, next_tools: %i[show_day]
    agent_tool :update_priority, on: :update, title: "Tick off a priority",
      description: "done: true or false, for a line of one's own. Work is done when the work itself is marked done.",
      params: { priority: { done: "boolean!" } }
    agent_tool :remove_priority, on: :destroy, title: "Take a priority off someone's day"
    agent_tool :move_priority, on: :move, title: "Reorder a priority in someone's day",
      description: "direction: up, down, top or bottom; or before_id: another priority that day to put it just before. Their day's list is in show_day.",
      params: { direction: %w[up down top bottom], before_id: "integer" }
    agent_tool :carry_over_priorities, on: :carry_over, title: "Carry over yesterday's unfinished priorities",
      description: "Adds the previous weekday's priorities that weren't done to the day. user_id: whose (you, if left out); day: today if left out.",
      params: { user_id: "integer", day: "date" }

    def create
      attributes = params.expect(priority: %i[user_id day todo_id title])
      todo = ::Todo.find(attributes[:todo_id]) if attributes[:todo_id].present?
      person = person_for(attributes[:user_id].presence || todo&.owner_id)
      priority = Priority.new(user: person, day: Day.parse(attributes[:day]), todo: todo,
        title: (attributes[:title] unless todo), added_by: Current.user.person)

      if priority.save
        redirect_back fallback_location: meetings_day_path(priority.day.iso8601, user_id: person.id),
          notice: "#{priority.label} is a priority for #{person.display_name} on #{I18n.l(priority.day, format: :long)}."
      else
        redirect_back fallback_location: meetings_today_path, alert: priority.errors.full_messages.to_sentence
      end
    end

    def update
      priority = Priority.find(params[:id])
      done = ActiveModel::Type::Boolean.new.cast(params.expect(priority: [ :done ])[:done])
      priority.mark!(done)
      redirect_back fallback_location: meetings_today_path, notice: "#{priority.label}: #{done ? "done" : "not done yet"}."
    rescue ArgumentError => e
      redirect_back fallback_location: meetings_today_path, alert: e.message
    end

    def destroy
      priority = Priority.find(params[:id])
      priority.destroy!
      redirect_back fallback_location: meetings_today_path, notice: "Took #{priority.label} off #{priority.user.display_name}’s day."
    end

    # Dragged (the core's drag-and-drop sends `before`, the one it now sits before) or moved by
    # its buttons (direction).
    def move
      priority = Priority.find(params[:id])
      dragged = params.key?(:before)
      dragged ? priority.move!(before: params[:before]) : (params[:direction].present? ? priority.shift!(params[:direction]) : priority.move!(before: params[:before_id]))
      # A drag has already moved it on the page; the buttons and agents get the page as it stands.
      return head(:no_content) if dragged && request.format.turbo_stream?

      place = priority.siblings.where(position: ...priority.reload.position).count + 1
      redirect_back fallback_location: meetings_day_path(priority.day.iso8601, priority.user_id),
        notice: "#{priority.label} is #{place.ordinalize} on #{priority.user.display_name}’s day."
    rescue ArgumentError => e
      redirect_back fallback_location: meetings_today_path, alert: e.message
    end

    def carry_over
      day = Day.new(person_for(params[:user_id]), Day.parse(params[:day]))
      carried = day.carry_over!(by: Current.user.person)
      message = carried.any? ? "Carried over #{carried.size} from #{I18n.l(day.previous_workday, format: :long)}." : "Nothing left over from #{I18n.l(day.previous_workday, format: :long)}."
      redirect_back fallback_location: meetings_day_path(day.date.iso8601, user_id: day.user.id), notice: message
    end

    private
      def person_for(id) = id.present? ? ::User.active.people.find(id) : Current.user.person
  end
end
