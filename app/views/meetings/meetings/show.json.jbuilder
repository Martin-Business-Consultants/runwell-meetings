json.merge! agent_ref(@meeting)
json.url meetings_meeting_url(@meeting)
json.summary "#{@meeting.title}, #{@meeting.when_label}: #{@priorities.map { |person, priorities| "#{person.display_name} #{priorities.count(&:done?)}/#{priorities.size} done" }.join(", ")}"
json.extract! @meeting, :title, :starts_at
json.day @meeting.day
json.agenda agent_text(@meeting.agenda)
json.notes agent_text(@meeting.notes)
json.people @priorities do |person, priorities|
  json.merge! agent_user(person)
  json.priorities priorities do |priority|
    json.id priority.id
    json.title priority.label
    json.done priority.done?
    json.status priority.status_label
    json.todo agent_ref(priority.todo) if priority.todo
  end
end
json.open_work_to_pick @todos do |todo|
  json.merge! agent_ref(todo)
  json.owner agent_user(todo.owner)
  json.due_on todo.due_on
end
