module Meetings
  # The "+" menu on a person's card (Team day): open work to make one of their priorities, theirs
  # first, narrowed to a client or an engagement and then by a fuzzy filter on the page. Loaded into
  # the menu's frame when it opens.
  class PicksController < ApplicationController
    allow_staff
    agent_exempt :index, reason: "The Team day + menu's list; agents read open work with show_day and list_work, and add it with add_priority."

    LIMIT = 300

    def index
      @person = ::User.active.people.find(params[:user_id])
      @date = Day.parse(params[:day])
      @scope = params[:scope].to_s
      taken = Priority.where(user: @person, day: @date).where.not(todo_id: nil).select(:todo_id)
      todos = ::Todo.open.where.not(id: taken).joins(engagement: :client).includes(:owner, { assignments: :user }, engagement: :client)
      todos = narrow(todos)
      @todos = todos.order(Arel.sql("CASE WHEN todos.id IN (#{::Todo.assigned_to(@person).select(:id).to_sql}) THEN 0 ELSE 1 END, todos.due_on IS NULL, todos.due_on, todos.id")).limit(LIMIT).to_a
      @clients = ::Client.where(id: ::Engagement.where(id: ::Todo.open.select(:engagement_id)).select(:client_id)).ordered
        .includes(:engagements).to_a
      @open_engagement_ids = ::Todo.open.distinct.pluck(:engagement_id).to_set
    end

    private
      def narrow(todos)
        kind, value = @scope.split(":", 2)
        case kind
        when "client" then todos.where(engagements: { client_id: value })
        when "engagement" then todos.where(engagements: { ref: value })
        else todos
        end
      end
  end
end
