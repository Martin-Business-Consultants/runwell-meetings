day = @day
json.summary "#{day.user.display_name}, #{day.label}: #{day.done_count} of #{day.priorities.size} priorities done, #{day.report&.persisted? ? "report written" : "no report yet"}"
json.date day.date
json.person agent_user(day.user)
json.priorities day.priorities do |priority|
  json.id priority.id
  json.title priority.label
  json.done priority.done?
  json.status priority.status_label
  json.todo agent_ref(priority.todo) if priority.todo
end
json.meetings day.meetings do |meeting|
  json.merge! agent_ref(meeting)
  json.url meetings_meeting_url(meeting)
  json.starts_at meeting.starts_at
end
if (report = day.report)&.persisted?
  json.report do
    Meetings::Report::FIELDS.each_key { |field| json.set! field, agent_text(report.public_send(field)) }
  end
else
  json.report nil
end
json.open_work day.open_work do |todo|
  json.merge! agent_ref(todo)
  json.status todo.status
  json.due_on todo.due_on
end
json.unfinished_from_previous_workday day.carry_over.map(&:label)
