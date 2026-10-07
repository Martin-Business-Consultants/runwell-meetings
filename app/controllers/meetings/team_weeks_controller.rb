module Meetings
  # Everyone's week at once, a row per person and a column per day.
  class TeamWeeksController < ApplicationController
    allow_staff
    agent_tool :show_team_week, on: :show, title: "Show the team's week",
      description: "Each person's priorities for each day of a week (Monday to Sunday; done or not) and which days they reported. date: any day in the week (this week if left out); series_id: only the people of that repeating meeting (list_meeting_series).",
      params: { date: "date", series_id: "integer" }, next_tools: %i[show_team_day add_priority]

    def show
      series = Series.find_by(id: params[:series_id]) if params[:series_id].present?
      @week = TeamWeek.new(Day.parse(params[:date]), series: series)
      @all_series = Series.active.ordered.to_a
    end
  end
end
