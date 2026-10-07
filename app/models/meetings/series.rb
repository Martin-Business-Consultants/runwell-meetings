module Meetings
  # A repeating meeting: every weekday, on chosen days every week or every two weeks, or monthly on
  # the same weekday (the second Tuesday). Each occurrence is an ordinary meeting, planned a week
  # ahead (and at least the next one, however far off) when the series is saved and each night.
  # Changing the series changes its meetings that haven't started; one deleted on its own stays
  # skipped. Stopping it removes the upcoming ones nobody has written in.
  class Series < ::ApplicationRecord
    self.table_name = "meetings_series"

    FREQUENCIES = {
      "weekdays" => "Every weekday",
      "weekly" => "Every week",
      "biweekly" => "Every two weeks",
      "monthly" => "Every month"
    }.freeze
    # Monday first, as people read a week.
    WEEKDAYS = { 1 => "Mon", 2 => "Tue", 3 => "Wed", 4 => "Thu", 5 => "Fri", 6 => "Sat", 0 => "Sun" }.freeze
    WEEKDAY_KEYS = WEEKDAYS.to_h { |wday, name| [ name.downcase, wday ] }.freeze
    AHEAD = 7.days

    belongs_to :created_by, class_name: "::User", optional: true
    has_many :meetings, class_name: "Meetings::Meeting", inverse_of: :series, dependent: :nullify

    validates :title, :starts_on, presence: true
    validates :frequency, inclusion: { in: FREQUENCIES.keys, message: "must be one of #{FREQUENCIES.keys.to_sentence(last_word_connector: " or ")}" }
    validates :time_of_day, format: { with: /\A\d{1,2}:\d{2}\z/, message: "must be a time like 09:30" }
    validate :ends_after_it_starts

    before_validation :clear_empty_agenda
    before_validation { self.weekdays = nil unless repeats_on_weekdays? }

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:time_of_day, :title) }

    def self.plan_all_ahead! = active.find_each(&:plan_ahead!)

    # Days of the week (0 Sunday … 6 Saturday) for weekly and every-two-weeks series: those chosen,
    # else the first meeting's.
    def weekday_list
      list = weekdays.to_s.split(",").map(&:to_i) & WEEKDAYS.keys
      list.presence || [ starts_on&.wday ].compact
    end

    def weekday_list=(values)
      self.weekdays = Array(values).compact_blank.map { WEEKDAY_KEYS.fetch(it.to_s.downcase[0, 3]) { Integer(it, exception: false) } }.compact.uniq.sort.join(",").presence
    end

    def repeats_on_weekdays? = frequency.in?(%w[weekly biweekly])

    def people = ::User.active.people.where(id: person_ids).ordered

    def label
      days = WEEKDAYS.keys.select { weekday_list.include?(it) }.map { Date::DAYNAMES[it] }
      rule = case frequency
      when "weekdays" then "Every weekday"
      when "weekly" then "Every #{days.to_sentence}"
      when "biweekly" then "Every other #{days.to_sentence}"
      when "monthly" then "The #{ordinal} #{starts_on.strftime("%A")} of each month"
      end
      "#{rule} at #{Time.zone.parse(time_of_day).strftime("%-l:%M %p").downcase}#{", until #{I18n.l(ends_on, format: :long)}" if ends_on}"
    end

    def occurs_on?(date)
      return false if date < starts_on || (ends_on && date > ends_on)

      case frequency
      when "weekdays" then date.on_weekday?
      when "weekly" then weekday_list.include?(date.wday)
      when "biweekly" then weekday_list.include?(date.wday) && ((date.beginning_of_week - starts_on.beginning_of_week).to_i / 7).even?
      when "monthly" then date.wday == starts_on.wday && monthly_week?(date)
      else false
      end
    end

    # The dates it meets from one day to another.
    def dates_between(from, to) = (from..to).select { occurs_on?(it) }

    # Its next date on or after a day, if it has one in the coming year.
    def next_on(from = Date.current) = (from..(from + 400)).find { occurs_on?(it) && !skipped?(it) }

    def skipped?(date) = skipped_on.include?(date.iso8601)

    def skip!(date)
      update_columns(skipped_on: (skipped_on | [ date.iso8601 ]), updated_at: Time.current) unless skipped?(date)
    end

    # Plans its meetings for the coming week, and the next one if none falls in it. Returns those
    # it planned.
    def plan_ahead!
      return [] unless active?

      from = [ starts_on, Date.current ].max
      planned_days = meetings.where(starts_at: from.in_time_zone..).pluck(:starts_at).map { it.in_time_zone.to_date }.to_set
      dates = dates_between(from, Date.current + AHEAD).reject { skipped?(it) || planned_days.include?(it) }
      if dates.empty? && planned_days.none?
        next_date = next_on(from)
        dates = [ next_date ] if next_date
      end
      ids = people.ids
      dates.map { plan_on(it, ids) }
    end

    # Saves a change to the rule, title, time, people or agenda, and carries it to every meeting
    # it has that hasn't started: those off the new rule go (or, if someone wrote in them, leave the
    # series), the rest take the new title, time and people, and an agenda nobody changed follows.
    def revise!(attributes)
      previous_agenda = agenda
      assign_attributes(attributes)
      return false unless valid?

      transaction do
        save!
        ids = people.ids
        meetings.where(starts_at: Time.current..).find_each do |meeting|
          if occurs_on?(meeting.day) && !skipped?(meeting.day)
            meeting.update!(title: title, starts_on: meeting.day, starts_at_time: time_of_day,
              agenda: (meeting.agenda.blank? || meeting.agenda == previous_agenda ? agenda : meeting.agenda))
            meeting.replace_people!(ids)
          else
            written_in?(meeting, previous_agenda) ? meeting.update!(series: nil) : meeting.unplan!
          end
        end
        plan_ahead!
      end
      true
    end

    # Stops repeating: its upcoming meetings nobody wrote in go; those with notes or their own
    # agenda stay, as one-offs.
    def stop!
      transaction do
        update!(active: false, ends_on: [ Date.current, starts_on ].max)
        meetings.where(starts_at: Time.current..).find_each do |meeting|
          written_in?(meeting, agenda) ? meeting.update!(series: nil) : meeting.unplan!
        end
      end
    end

    def upcoming_meetings = meetings.where(starts_at: Time.current.beginning_of_day..).order(:starts_at)

    private
      def plan_on(date, user_ids)
        meeting = meetings.create!(title: title, starts_on: date, starts_at_time: time_of_day, agenda: agenda, created_by_id: created_by_id)
        meeting.replace_people!(user_ids)
        meeting
      end

      def written_in?(meeting, template) = meeting.notes.present? || (meeting.agenda.present? && meeting.agenda != template)

      # Which week of the month starts_on falls in; past the fourth means the last.
      def week_of_month(date) = (date.day - 1) / 7

      def monthly_week?(date)
        nth = week_of_month(starts_on)
        nth >= 4 ? (date + 7).month != date.month : week_of_month(date) == nth
      end

      def ordinal = week_of_month(starts_on) >= 4 ? "last" : %w[first second third fourth][week_of_month(starts_on)]

      def ends_after_it_starts
        errors.add(:ends_on, "must be on or after its first day") if ends_on && starts_on && ends_on < starts_on
      end

      def clear_empty_agenda
        self.agenda = nil if ActionController::Base.helpers.strip_tags(agenda.to_s).squish.blank?
      end
  end
end
