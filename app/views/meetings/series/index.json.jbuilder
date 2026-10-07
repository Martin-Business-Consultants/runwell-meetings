json.summary "#{pluralize(@series.size, "repeating meeting")}#{" (stopped ones too)" if @all}"
json.series @series do |series|
  json.id series.id
  json.extract! series, :title, :frequency, :time_of_day, :starts_on, :ends_on, :active
  json.weekdays(series.repeats_on_weekdays? ? Meetings::Series::WEEKDAYS.slice(*series.weekday_list).values.map(&:downcase) : nil)
  json.rule series.label
  json.people series.person_ids.filter_map { @people[it] }.map { agent_user(it) }
  json.agenda agent_text(series.agenda)
  if (upcoming = @next[series.id])
    json.next_meeting do
      json.merge! agent_ref(upcoming)
      json.url meetings_meeting_url(upcoming)
      json.starts_at upcoming.starts_at
    end
  end
end
