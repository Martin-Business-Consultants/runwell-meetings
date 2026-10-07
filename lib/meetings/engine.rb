module Meetings
  # A Runwell plugin for a team's rhythm: meetings with an agenda and notes, each person's
  # priorities for the day (picked from their work, or a line of their own), and at the end of the
  # day a report on what went well, what didn't, and why. It owns its tables and reaches the core
  # only through the plugin contract. Remove it and Runwell runs as before.
  class Engine < ::Rails::Engine
    # Routes join the app's route set (as meetings_*), so the core layout's helpers work here.
    initializer "meetings.routes" do |app|
      app.routes.append do
        scope "meetings", module: "meetings", as: "meetings" do
          get "today", to: "days#show", as: :today
          get "days/:date(/:user_id)", to: "days#show", as: :day, constraints: { date: /\d{4}-\d{2}-\d{2}/, user_id: /\d+/ }
          resources :priorities, only: %i[create update destroy] do
            post :carry_over, on: :collection
          end
          resources :reports, only: %i[index create]
          resources :meetings, path: "", constraints: { id: /\d+/ } do
            post :plan_next, on: :member
          end
        end
      end
    end

    initializer "meetings.models" do
      ActiveSupport.on_load(:runwell_user) do
        has_many :meetings_priorities, class_name: "Meetings::Priority", dependent: :delete_all
        has_many :meetings_reports, class_name: "Meetings::Report", dependent: :delete_all
        has_many :meetings_attendees, class_name: "Meetings::Attendee", dependent: :delete_all
      end
      ActiveSupport.on_load(:runwell_todo) do
        has_many :meetings_priorities, class_name: "Meetings::Priority", dependent: :delete_all
      end
    end

    config.to_prepare do
      Runwell::Plugins.register :meetings, name: "Meetings", version: Meetings::VERSION, author: "Runwell",
        enabled_by_default: false, requires: ">= 2.21.0", homepage: "https://github.com/Martin-Business-Consultants/runwell-meetings",
        description: "Team meetings with agendas and notes, each person’s priorities for the day picked from their work, and an end-of-day report on what went well, what didn’t, and why."
      Runwell::Plugins.nav :meetings, "Meetings", -> { meetings_today_path }
      Runwell::Plugins.slot :home_top, :meetings, "meetings/slots/home_top"
      Runwell::Plugins.stylesheet :meetings, "meetings/meetings"
      Runwell::Plugins.agent_workflow :meetings, "Plan the day and report on it", <<~TEXT
        In the morning: `show_day` for the person (today by default) shows their priorities, their open work and yesterday's unfinished priorities. Add the few that matter with `add_priority` (a todo_id, or a title for anything that isn't work), or `carry_over_priorities`.
        Before a team meeting: `show_meeting` lists each person with their priorities for its day, and the agenda.
        At the end of the day: `show_day` again for what got done, then `save_daily_report` with what went well, what didn't, why, and what's next. Ask the person; don't invent their answers.
      TEXT
    end
  end
end
