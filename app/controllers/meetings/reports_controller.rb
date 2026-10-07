module Meetings
  # End-of-day reports: each person's look back at their day, read by the team a day at a time.
  class ReportsController < ApplicationController
    allow_staff
    agent_tool :list_daily_reports, on: :index, title: "Read the team's end-of-day reports",
      description: "Everyone's report for a day (today if left out), with how many of their priorities got done. user_id: one person's, for the last 30 days instead.",
      params: { date: "date", user_id: "integer" }
    agent_tool :save_daily_report, on: :create, title: "Write your end-of-day report",
      description: "How your day went: what went well, what didn't, why, and what's next. Saving again changes the fields you send and keeps the rest. day: today if left out. Ask the person; don't invent their answers.",
      params: { report: { day: "date", went_well: "text", went_badly: "text", why: "text", next_up: "text" } }

    def index
      @date = Day.parse(params[:date])
      @person = ::User.people.find_by(id: params[:user_id]) if params[:user_id].present?
      @people = ::User.active.people.ordered.to_a
      if @person
        @reports = Report.where(user: @person, day: (@date - 30)..@date).order(day: :desc).to_a
        @priorities = Priority.where(user: @person, day: @reports.map(&:day)).includes(:todo).group_by(&:day)
      else
        @reports = Report.where(day: @date).to_a.index_by(&:user_id)
        @priorities = Priority.where(day: @date, user_id: @people.map(&:id)).includes(:todo).group_by(&:user_id)
      end
    end

    def create
      attributes = params.expect(report: %i[day went_well went_badly why next_up])
      person = Current.user.person
      report = Report.find_or_initialize_by(user: person, day: Day.parse(attributes.delete(:day)))
      report.assign_attributes(attributes)

      if report.save
        redirect_to meetings_day_path(report.day.iso8601), notice: "Saved your report for #{I18n.l(report.day, format: :long)}."
      else
        @day = Day.new(person, report.day).tap { it.report = report }
        @mine = true
        render "meetings/days/show", status: :unprocessable_entity
      end
    end
  end
end
