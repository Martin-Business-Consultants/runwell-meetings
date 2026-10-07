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
    agent_tool :plan_meeting, on: :create, title: "Plan a team meeting, once or repeating",
      description: "starts_on and starts_at_time (24h, \"09:30\") in the install's time zone. person_ids: who's in it (you, if left out). The priorities it shows are each person's for that day. To repeat it: repeats weekdays (Monday to Friday), weekly or biweekly (on repeat_weekdays, e.g. [\"mon\", \"thu\"]; starts_on's weekday if none), or monthly (the same weekday of the month as starts_on, e.g. the second Tuesday); repeat_until: the last day, or never. The agenda then starts each one.",
      params: { meeting: { title: "string!", starts_on: "date!", starts_at_time: "string", person_ids: "integer[]", agenda: "text",
        repeats: %w[none weekdays weekly biweekly monthly], repeat_weekdays: "string[]", repeat_until: "date" } },
      next_tools: %i[show_meeting add_priority]
    agent_tool :update_meeting, on: :update, title: "Change a team meeting",
      description: "This one meeting: its title, time, people, agenda, or the notes taken in it. person_ids replaces everyone in it. For a repeating one, update_meeting_series changes every one to come. A one-off can start repeating with repeats (as in plan_meeting), from its day.",
      params: { meeting: { title: "string", starts_on: "date", starts_at_time: "string", person_ids: "integer[]", agenda: "text", notes: "text",
        repeats: %w[none weekdays weekly biweekly monthly], repeat_weekdays: "string[]", repeat_until: "date" } }
    agent_tool :plan_next_meeting, on: :plan_next, title: "Plan the next one",
      description: "The same meeting (title, time, people) on the next weekday, with an empty agenda. Answers the one already there if it exists."
    agent_tool :delete_meeting, on: :destroy, title: "Delete a team meeting",
      description: "Whoever planned it, or someone who may delete records. Priorities stay: they belong to each person's day. One of a repeating series is skipped, not planned again; stop_meeting_series ends the series."

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
      series = build_series

      if series
        start_series(series)
      elsif @meeting.save
        redirect_to meetings_meeting_path(@meeting), notice: "Planned #{@meeting.title} for #{@meeting.when_label}, with #{@meeting.people.map(&:display_name).to_sentence}."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      @meeting.assign_attributes(meeting_params)
      series = build_series unless @meeting.series

      if series
        start_series(series)
      elsif @meeting.save
        redirect_to meetings_meeting_path(@meeting), notice: "Saved #{@meeting.title}#{" (this one only; the series is unchanged)" if @meeting.series}."
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
        attributes = params.expect(meeting: [ :title, :starts_on, :starts_at_time, :agenda, :notes, :repeats, :repeat_until, person_ids: [], repeat_weekdays: [] ])
        @repeat = attributes.extract!(:repeats, :repeat_until, :repeat_weekdays)
        attributes[:person_ids] = ::User.active.people.where(id: attributes[:person_ids].compact_blank).ids if attributes.key?(:person_ids)
        attributes
      end

      # A series when the form asks for the meeting to repeat: its rule from the form, the rest
      # from the meeting.
      def build_series
        frequency = @repeat[:repeats].presence_in(Series::FREQUENCIES.keys) or return
        Series.new(title: @meeting.title, frequency: frequency, weekday_list: @repeat[:repeat_weekdays], ends_on: @repeat[:repeat_until].presence,
          time_of_day: @meeting.starts_at_time, starts_on: @meeting.starts_on, person_ids: @meeting.person_ids,
          agenda: @meeting.agenda, created_by: @meeting.created_by || Current.user.person)
      end

      # Saves the series and plans its first week. A meeting already saved (a one-off made to
      # repeat) becomes its first occurrence when it falls on the rule; a new one is planned by
      # the series itself.
      def start_series(series)
        meeting_valid = @meeting.valid?
        unless meeting_valid && series.valid?
          series.errors.each { @meeting.errors.add(:base, "Repeats: #{it.full_message.downcase_first}") }
          return render(@meeting.persisted? ? :edit : :new, status: :unprocessable_entity)
        end

        Series.transaction do
          series.save!
          if @meeting.persisted?
            @meeting.series = series if series.occurs_on?(@meeting.day)
            @meeting.save!
          end
          series.plan_ahead!
        end
        first = series.upcoming_meetings.first || @meeting
        redirect_to meetings_meeting_path(first), notice: "#{series.title} repeats: #{series.label.downcase_first}. The coming week is planned; each night plans the next day."
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
