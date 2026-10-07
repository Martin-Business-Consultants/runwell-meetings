module Meetings
  # One person's day: their priorities, the meetings they're in, and their end-of-day report.
  class DaysController < ApplicationController
    allow_staff
    agent_tool :show_day, on: :show, title: "Show someone's day",
      description: "Their priorities for the day (done or not), the meetings they're in, their report if written, their open work to pick priorities from, and yesterday's unfinished priorities. date: YYYY-MM-DD, today if left out; user_id: you if left out.",
      params: { date: "date", user_id: "integer" }, next_tools: %i[add_priority save_daily_report]

    def show
      person = params[:user_id].present? ? ::User.people.find(params[:user_id]) : Current.user.person
      @day = Day.new(person, Day.parse(params[:date]))
      @mine = @day.user == Current.user.person
    end
  end
end
