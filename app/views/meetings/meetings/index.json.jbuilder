json.summary "#{pluralize(@meetings.size, "#{"#{@state} " unless @state == "all"}meeting")}#{" you're in" if @mine}"
json.meetings @meetings do |meeting|
  json.merge! agent_ref(meeting)
  json.url meetings_meeting_url(meeting)
  json.extract! meeting, :title, :starts_at
  json.day meeting.day
  json.people meeting.people.map { agent_user(it) }
end
