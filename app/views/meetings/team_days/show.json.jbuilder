team = @team
json.summary "#{team.label}#{" (#{team.meeting.title})" if team.meeting}: #{team.done_count} of #{team.total_count} priorities done across #{team.people.size} people, #{team.reports.size} reported"
json.date team.date
json.meeting(team.meeting && { id: team.meeting.id, title: team.meeting.title })
json.people team.people do |person|
  json.merge! agent_user(person)
  json.priorities team.priorities_for(person) do |priority|
    json.id priority.id
    json.title priority.label
    json.done priority.done?
    json.status priority.status_label
    json.todo agent_ref(priority.todo) if priority.todo
  end
  if (report = team.report_for(person))
    json.report do
      Meetings::Report::FIELDS.each_key { |field| json.set! field, agent_text(report.public_send(field)) }
    end
  else
    json.report nil
  end
end
