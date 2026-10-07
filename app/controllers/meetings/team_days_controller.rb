module Meetings
  # Everyone's day at once, to go through together.
  class TeamDaysController < ApplicationController
    allow_staff
    agent_tool :show_team_day, on: :show, title: "Show the team's day",
      description: "Everyone's priorities for a day (done or not) and their end-of-day reports, side by side. date: YYYY-MM-DD, today if left out; meeting_id: only the people in that meeting.",
      params: { date: "date", meeting_id: "integer" }, next_tools: %i[add_priority move_priority]

    def show
      date = Day.parse(params[:date])
      meeting = Meeting.find_by(id: params[:meeting_id]) if params[:meeting_id].present?
      @team = TeamDay.new(date, meeting: meeting)
    end
  end
end
