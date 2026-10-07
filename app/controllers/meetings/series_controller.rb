module Meetings
  # Repeating meetings: the rule, and the change carried to every meeting still to come.
  class SeriesController < ApplicationController
    allow_staff
    agent_tool :list_meeting_series, on: :index, title: "List repeating meetings",
      description: "Each repeating meeting's rule, people and next date; stopped ones too with all: true.",
      params: { all: "boolean" }
    agent_tool :update_meeting_series, on: :update, title: "Change a repeating meeting",
      description: "Changes every one of its meetings that hasn't started: frequency (weekdays, weekly, biweekly, monthly), weekdays for weekly and biweekly ([\"mon\", \"thu\"]), time_of_day (\"09:30\"), title, person_ids (replaces everyone), agenda (follows into meetings whose agenda nobody changed), ends_on. Past meetings stay as they were.",
      params: { series: { title: "string", frequency: %w[weekdays weekly biweekly monthly], weekdays: "string[]", time_of_day: "string",
        person_ids: "integer[]", agenda: "text", ends_on: "date" } }
    agent_tool :stop_meeting_series, on: :stop, title: "Stop a meeting repeating",
      description: "No more are planned. Upcoming ones nobody wrote notes or their own agenda in are removed; past ones stay."

    before_action :set_series, except: :index

    def index
      @all = ActiveModel::Type::Boolean.new.cast(params[:all])
      @series = (@all ? Series.all : Series.active).ordered.to_a
      @next = Meeting.where(series_id: @series.map(&:id), starts_at: Time.current..).order(:starts_at).group_by(&:series_id).transform_values(&:first)
      @people = ::User.where(id: @series.flat_map(&:person_ids)).index_by(&:id)
    end

    def edit
    end

    def update
      if @series.revise!(series_params)
        redirect_to meetings_series_index_path, notice: "#{@series.title}: #{@series.label.downcase_first}. Its meetings to come are changed."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def stop
      return redirect_to(meetings_series_index_path, alert: "#{@series.title} already stopped.") unless @series.active?

      @series.stop!
      redirect_to meetings_series_index_path, notice: "#{@series.title} stopped repeating. Its past meetings stay."
    end

    private
      def set_series = @series = Series.find(params[:id])

      def series_params
        attributes = params.expect(series: [ :title, :frequency, :time_of_day, :agenda, :ends_on, person_ids: [], weekdays: [] ])
        attributes[:weekday_list] = attributes.delete(:weekdays) if attributes.key?(:weekdays)
        attributes[:person_ids] = ::User.active.people.where(id: attributes[:person_ids].compact_blank).ids if attributes.key?(:person_ids)
        attributes
      end
  end
end
