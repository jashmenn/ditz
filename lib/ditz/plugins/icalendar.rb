## icalendar ditz plugin
## 
## This plugin adds ability to export full todo list in iCalendar (RFC 2445) format. 
## It is useful for integration with different pim software like KOrganizer.
##
## Issues are converted to VTODO entries with completion status set to 50 if
## its state is :in_progress, 100 if it's closed and 0 otherwise.
## Progress for release is 100 if it's released otherwise it's 99 * closed/all 
## issues. So maximum for active release is 99 and it's not shown as done until 
## released.
##
## Commands added:
##   ditz todo-ics: set the git branch of an issue
##
## Usage: 
##   1. add a line "- icalendar" to the .ditz-plugins file in the project root

require 'vpim/icalendar'

module Ditz

class Operator
  operation :todo_ics, "Generate full todo list in iCalendar format", :maybe_release
  def todo_ics project, config, releases
    cal = Vpim::Icalendar.create
    releases ||= project.releases + [:unassigned]
    releases = [*releases]
    releases.each do |r|
      issues = project.issues_for_release r
      done = 0
      done = (99 * (issues.select { |i| i.closed? }).length / issues.length).to_int if issues.length != 0
      if r != :unassigned
        done = 100 if r.released?
        parent = "release-#{r.hash}"
        title = "Release #{r.name} (#{r.status})"
      else
        parent = "release-unassigned"
        title = "Unassigned"
      end
      cal.push Vpim::Icalendar::Vtodo.create("SUMMARY" => title, "UID" => parent, "PERCENT-COMPLETE" => "#{done}")
      issues.each do |i|
        cal.push todo2vtodo(i, parent)
      end
    end
    puts cal.encode
  end

  def todo2vtodo todo, parent
    h = {"SUMMARY" => "#{todo.title}", "UID" => "#{todo.type}-#{todo.id}"}
    h["RELATED-TO"] = parent if parent
    h["PRIORITY"] = "3" if todo.type == :bugfix
    h["PERCENT-COMPLETE"] = case todo.status
                            when :closed
                              "100"
                            when :in_progress
                              "50"
                            else
                              "0"
                            end
    return Vpim::Icalendar::Vtodo.create(h)
  end
end

end
