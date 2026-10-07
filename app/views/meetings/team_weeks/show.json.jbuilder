week = @week
json.summary "Week of #{week.starts_on.iso8601}#{" (#{week.series.title})" if week.series}: #{week.done_count} of #{week.total_count} priorities done across #{week.people.size} people"
json.starts_on week.starts_on
json.ends_on week.ends_on
json.series(week.series && { id: week.series.id, title: week.series.title })
json.people week.people do |person|
  json.merge! agent_user(person)
  json.days week.days do |day|
    json.date day
    json.reported week.report_for(person, day).present?
    json.priorities week.priorities_for(person, day) do |priority|
      json.id priority.id
      json.title priority.label
      json.done priority.done?
      json.status priority.status_label
      json.todo agent_ref(priority.todo) if priority.todo
    end
  end
end
