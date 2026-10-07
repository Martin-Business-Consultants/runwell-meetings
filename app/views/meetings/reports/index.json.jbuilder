if @person
  json.summary "#{@reports.size} reports from #{@person.display_name} in the last 30 days"
  json.person agent_user(@person)
  json.reports @reports do |report|
    priorities = @priorities.fetch(report.day, [])
    json.day report.day
    json.priorities_done "#{priorities.count(&:done?)} of #{priorities.size}"
    Meetings::Report::FIELDS.each_key { |field| json.set! field, agent_text(report.public_send(field)) }
  end
else
  json.summary "#{@reports.size} of #{@people.size} people reported on #{@date.iso8601}"
  json.date @date
  json.people @people do |person|
    report = @reports[person.id]
    priorities = @priorities.fetch(person.id, [])
    json.merge! agent_user(person)
    json.priorities_done "#{priorities.count(&:done?)} of #{priorities.size}"
    if report
      json.report do
        Meetings::Report::FIELDS.each_key { |field| json.set! field, agent_text(report.public_send(field)) }
      end
    else
      json.report nil
    end
  end
end
