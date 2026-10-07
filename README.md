# Meetings, a Runwell plugin

A team's daily rhythm in [Runwell](https://github.com/Martin-Business-Consultants/runwellv2):

- **My day**: each person picks the few things that matter today, from their open work or as a
  line of their own (a call, an errand), and carries over what didn't get done yesterday. They're
  in the person's own order: drag one to reorder (the core's drag-and-drop), kept by the core's
  positioning gem.
- **Team day**: everyone's priorities and reports for a day side by side, to go through together;
  narrowed to one meeting's people from that meeting (Team day) or its filter. The + on each
  person's card opens a fuzzy finder of open work (theirs first), narrowed to a client or an
  engagement, or takes a line of their own.
- **Meetings**: an agenda and notes, and the meeting room: everyone in the meeting with their
  priorities for its day on the right, and open work to pick from on the left. Search either side;
  add work to anyone's day from its + menu. "Plan the next one" repeats a one-off on the next weekday.
- **Repeating meetings**: every weekday, on chosen days every week or every two weeks, or monthly
  on the same weekday (the second Tuesday), optionally until a date. The coming week is planned and
  each night plans further. Change the series (Repeating) and every meeting still to come follows;
  delete one and it stays skipped; stop it and the empty upcoming ones go.
- **End-of-day report**: what went well, what didn't, why, and what's next, read beside the day's
  priorities, done or not. Reports shows the whole team's for a day, or one person's month.

Home shows your priorities for today, your next meeting, and from 3pm a nudge to report.

Work done or not comes from the work itself (its status); lines of one's own are ticked off here.

## Tables

| Table | Holds |
| --- | --- |
| `meetings_meetings` | Title, start, agenda, notes, and its series if it repeats |
| `meetings_series` | A repeating meeting's rule, time, people, agenda for each, and skipped days |
| `meetings_attendees` | Who's in each meeting (`user_id`) |
| `meetings_priorities` | One person's priority for one day: a `todo_id`, or a `title` of their own |
| `meetings_reports` | One person's report for one day |

## Agent tools

`show_day`, `show_team_day`, `add_priority`, `update_priority`, `move_priority`, `remove_priority`,
`carry_over_priorities`,
`list_meetings`, `show_meeting`, `plan_meeting` (once or repeating), `update_meeting`,
`plan_next_meeting`, `delete_meeting`, `list_meeting_series`, `update_meeting_series`,
`stop_meeting_series`, `list_daily_reports`, `save_daily_report`, and the agent workflow
"Plan the day and report on it".

## Develop

From a Runwell checkout beside it: `bin/rails "plugins:link[../runwell-meetings]"`,
`bin/rails db:migrate`, `bin/dev`, then switch it on in Settings › Plugins.

## Release

Bump `lib/meetings/version.rb`, commit, then `git tag v0.4.2 && git push --tags`. The workflow
publishes the release; installs see it in Settings › Plugins and update when someone presses Update.
