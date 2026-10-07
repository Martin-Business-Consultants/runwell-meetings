module Meetings
  # A team meeting: who's in it, the agenda before, notes during, and each person's priorities for
  # its day, which it shows beside the open work they can be picked from.
  class Meeting < ::ApplicationRecord
    self.table_name = "meetings_meetings"

    belongs_to :created_by, class_name: "::User", optional: true
    belongs_to :series, class_name: "Meetings::Series", optional: true, inverse_of: :meetings
    has_many :attendees, class_name: "Meetings::Attendee", dependent: :delete_all
    has_many :people, -> { ordered }, through: :attendees, source: :user

    attribute :starts_on, :date
    attribute :starts_at_time, :string

    scope :upcoming, -> { where(starts_at: Time.current.beginning_of_day..).order(:starts_at) }
    scope :past, -> { where(starts_at: ...Time.current.beginning_of_day).order(starts_at: :desc) }
    scope :recent, -> { order(starts_at: :desc) }
    scope :on_day, ->(day) { where(starts_at: day.in_time_zone.all_day) }
    scope :with_person, ->(user) { where(id: Attendee.where(user: user).select(:meeting_id)) }

    validates :title, :starts_at, presence: true

    before_validation :combine_start
    before_validation :clear_empty_text
    after_initialize :split_start
    # A repeating meeting deleted on its own isn't planned again; one its series removes may be.
    before_destroy { series&.skip!(day) unless @unplanned }

    # The day whose priorities it covers.
    def day = starts_at.in_time_zone.to_date
    def today? = day == Date.current

    # Each person in it, with their priorities for its day, the work loaded in one pass.
    def priorities_by_person
      @priorities_by_person ||= begin
        priorities = Priority.where(user_id: attendees.select(:user_id), day: day).ordered.includes(:added_by, todo: [ :owner, { engagement: :client } ]).to_a
        people.to_a.index_with { |person| priorities.select { it.user_id == person.id } }
      end
    end

    # Its series takes it off the plan (a changed rule, or stopping), without skipping its day.
    def unplan!
      @unplanned = true
      destroy!
    end

    # Everyone in it, by id, without looking each person up (a series sets many meetings at once).
    def replace_people!(user_ids)
      attendees.delete_all
      Attendee.insert_all(user_ids.map { { meeting_id: id, user_id: it, created_at: Time.current, updated_at: Time.current } }) if user_ids.any?
      attendees.reset
      people.reset
    end

    def deletable_by?(person) = person.person == created_by || person.can?(:delete_records)

    # The same meeting on the next weekday after this one: its title, time and people, a fresh
    # agenda. Returns the one already planned there, if any.
    def plan_next!(by:)
      next_day = day.next_day
      next_day = next_day.next_day while next_day.saturday? || next_day.sunday?
      existing = Meeting.on_day(next_day).find_by(title: title)
      return existing if existing

      Meeting.create!(title: title, starts_on: next_day, starts_at_time: starts_at.in_time_zone.strftime("%H:%M"),
        person_ids: attendees.pluck(:user_id), created_by: by)
    end

    def when_label = I18n.l(starts_at.in_time_zone, format: :short)
    def label = "#{title}, #{when_label}"
    def search_title = label

    private
      def combine_start
        return if starts_on.blank?

        hour, minute = starts_at_time.to_s.split(":").map(&:to_i)
        self.starts_at = Time.zone.local(starts_on.year, starts_on.month, starts_on.day, hour || 9, minute || 0)
      end

      def split_start
        return if starts_at.nil? || starts_on.present?

        local = starts_at.in_time_zone
        self.starts_on = local.to_date
        self.starts_at_time = local.strftime("%H:%M")
      end

      def clear_empty_text
        %i[agenda notes].each { |field| self[field] = nil if ActionController::Base.helpers.strip_tags(self[field].to_s).squish.blank? }
      end
  end
end
