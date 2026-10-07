module Meetings
  # Team meetings: who's in it, the agenda and notes, and each person's priorities for its day
  # beside the open work they can be picked from.
  class MeetingsController < ApplicationController
    allow_staff
    agent_tool :list_meetings, on: :index, title: "List team meetings",
      description: "Upcoming meetings (from today), past ones, or all; mine: only those you're in.",
      params: { state: %w[upcoming past all], mine: "boolean" }
    agent_tool :show_meeting, on: :show, title: "Show a team meeting",
      description: "Its agenda and notes, and each person in it with their priorities for its day (work or their own lines, done or not)."
    agent_tool :plan_meeting, on: :create, title: "Plan a team meeting",
      description: "starts_on and starts_at_time (24h, \"09:30\") in the install's time zone. person_ids: who's in it (you, if left out). The priorities it shows are each person's for that day.",
      params: { meeting: { title: "string!", starts_on: "date!", starts_at_time: "string", person_ids: "integer[]", agenda: "text" } },
      next_tools: %i[show_meeting add_priority]
    agent_tool :update_meeting, on: :update, title: "Change a team meeting",
      description: "Its title, time, people, agenda, or the notes taken in it. person_ids replaces everyone in it.",
      params: { meeting: { title: "string", starts_on: "date", starts_at_time: "string", person_ids: "integer[]", agenda: "text", notes: "text" } }
    agent_tool :plan_next_meeting, on: :plan_next, title: "Plan the next one",
      description: "The same meeting (title, time, people) on the next weekday, with an empty agenda. Answers the one already there if it exists."
    agent_tool :delete_meeting, on: :destroy, title: "Delete a team meeting",
      description: "Whoever planned it, or someone who may delete records. Priorities stay: they belong to each person's day."

    before_action :set_meeting, except: %i[index new create]

    def index
      @view = index_view
      @state = params[:state].presence_in(%w[upcoming past all]) || "upcoming"
      @mine = ActiveModel::Type::Boolean.new.cast(params[:mine])
      scope = { "upcoming" => Meeting.upcoming, "past" => Meeting.past }.fetch(@state) { Meeting.recent }
      scope = scope.with_person(Current.user.person) if @mine
      @meetings = paginate scope.includes(:people)
    end

    def show
      @todos_query = params[:q].to_s.strip
      @people_query = params[:who].to_s.strip
      @priorities = @meeting.priorities_by_person
      @todos = todos_to_pick
    end

    def new
      @meeting = Meeting.new(starts_on: Date.current, starts_at_time: "09:00", person_ids: [ Current.user.person.id ])
    end

    def create
      @meeting = Meeting.new(meeting_params.merge(created_by: Current.user.person))
      @meeting.person_ids = [ Current.user.person.id ] if @meeting.attendees.empty?

      if @meeting.save
        redirect_to meetings_meeting_path(@meeting), notice: "Planned #{@meeting.title} for #{@meeting.when_label}, with #{@meeting.people.map(&:display_name).to_sentence}."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @meeting.update(meeting_params)
        redirect_to meetings_meeting_path(@meeting), notice: "Saved #{@meeting.title}."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def plan_next
      meeting = @meeting.plan_next!(by: Current.user.person)
      redirect_to meetings_meeting_path(meeting), notice: "#{meeting.title} is planned for #{meeting.when_label}. Write its agenda when you're ready."
    end

    def destroy
      return redirect_to(meetings_meeting_path(@meeting), alert: "Only whoever planned it, or someone who may delete records, can delete it.") unless @meeting.deletable_by?(Current.user)

      @meeting.destroy!
      redirect_to meetings_meetings_path, notice: "Deleted #{@meeting.title}."
    end

    private
      def set_meeting = @meeting = Meeting.find(params[:id])

      def meeting_params
        attributes = params.expect(meeting: [ :title, :starts_on, :starts_at_time, :agenda, :notes, person_ids: [] ])
        attributes[:person_ids] = ::User.active.people.where(id: attributes[:person_ids].compact_blank).ids if attributes.key?(:person_ids)
        attributes
      end

      # Open work to pick priorities from: what the search finds across everyone's, or else the
      # meeting's people's own, soonest due first. Work that's already a priority that day is left out.
      def todos_to_pick
        taken = @priorities.values.flatten.filter_map(&:todo_id)
        scope = ::Todo.open.where.not(id: taken).includes(:owner, engagement: :client)
        scope = if @todos_query.present?
          scope.joins(engagement: :client).where("todos.title LIKE :q OR engagements.title LIKE :q OR clients.name LIKE :q", q: "%#{::Todo.sanitize_sql_like(@todos_query)}%")
        else
          scope.where(owner_id: @priorities.keys.map(&:id))
        end
        scope.order(Arel.sql("todos.due_on IS NULL, todos.due_on, todos.id")).limit(60).to_a
      end
  end
end
