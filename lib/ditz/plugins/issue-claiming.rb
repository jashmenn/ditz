## issue-claiming ditz plugin
## 
## This plugin allows people to claim issues. This is useful for avoiding
## duplication of work---you can check to see if someone's claimed an
## issue before starting to work on it, and you can let people know what
## you're working on.
##
## Commands added:
##   ditz claim: claim an issue for yourself
##   ditz unclaim: unclaim a claimed issue
##   ditz mine: show all issues claimed by you
##   ditz claimed: show all claimed issues, by developer
##   ditz unclaimed: show all unclaimed issues
##
## Usage:
##   1. add a line "- issue-claiming" to the .ditz-plugins file in the project
##      root
##   2. use the above commands to abandon

module Ditz
class Issue
  field :claimer, :ask => false

  def claim who, comment, force=false
    raise Error, "already claimed by #{claimer}" if claimer && !force
    log "issue claimed", who, comment
    self.claimer = who
  end

  def unclaim who, comment, force=false
    raise Error, "not claimed" unless claimer
    raise Error, "can only be unclaimed by #{claimer}" unless claimer == who || force
    if claimer == who
      log "issue unclaimed", who, comment
    else
      log "unassigned from #{claimer}", who, comment
    end
    self.claimer = nil
  end

  def claimed?; claimer end
  def unclaimed?; !claimed? end
end

class ScreenView
  add_to_view :issue_summary do |issue, config|
    " Claimed by: #{issue.claimer || 'none'}\n"
  end
end

class HtmlView
  add_to_view :issue_summary do |issue, config|
    next unless issue.claimer
    [<<EOS, { :issue => issue }]
<tr>
  <td class='attrname'>Claimed by:</td>
  <td class='attrval'><%= h(issue.claimer) %></td>
</tr>
EOS
  end
end

class Operator
  alias :__issue_claiming_start :start
  def start project, config, opts, issue
    if issue.claimed? && issue.claimer != config.user
      raise Error, "issue #{issue.name} claimed by #{issue.claimer}"
    else
      __issue_claiming_start project, config, opts, issue
    end
  end

  alias :__issue_claiming_stop :stop
  def stop project, config, opts, issue
    if issue.claimed? && issue.claimer != config.user
      raise Error, "issue #{issue.name} claimed by #{issue.claimer}"
    else
      __issue_claiming_stop project, config, opts, issue
    end
  end

  alias :__issue_claiming_close :close
  def close project, config, opts, issue
    if issue.claimed? && issue.claimer != config.user
      raise Error, "issue #{issue.name} claimed by #{issue.claimer}"
    else
      __issue_claiming_close project, config, opts, issue
    end
  end

  operation :claim, "Claim an issue for yourself", :issue, :maybe_dev do
    opt :force, "Claim this issue even if someone else has claimed it", :default => false
  end
  def claim project, config, opts, issue, dev = nil
    new_claimer = dev || config.user
    puts "Claiming issue #{issue.name}: #{issue.title} for #{new_claimer}."
    comment = ask_multiline_or_editor "Comments" unless $opts[:no_comment]
    issue.claim new_claimer, comment, opts[:force]
    puts "Issue #{issue.name} marked as claimed by #{new_claimer}"
  end

  operation :unclaim, "Unclaim a claimed issue", :issue do
    opt :force, "Unclaim this issue even if it's claimed by someone else", :default => false
  end
  def unclaim project, config, opts, issue
    puts "Unclaiming issue #{issue.name}: #{issue.title}."
    comment = ask_multiline_or_editor "Comments" unless $opts[:no_comment]
    issue.unclaim config.user, comment, opts[:force]
    puts "Issue #{issue.name} marked as unclaimed."
  end

  operation :mine, "Show all issues claimed by you", :maybe_release do
    opt :all, "Show all issues, not just open ones"
  end
  def mine project, config, opts, releases
    releases ||= project.unreleased_releases + [:unassigned]
    releases = [*releases]

    issues = project.issues.select do |i|
      r = project.release_for(i.release) || :unassigned
      releases.member?(r) && i.claimer == config.user && (opts[:all] || i.open?)
    end
    if issues.empty?
      puts "No issues."
    else
      print_todo_list_by_release_for project, issues
    end
  end

  operation :claimed, "Show claimed issues by claimer", :maybe_release do
    opt :all, "Show all issues, not just open ones"
  end
  def claimed project, config, opts, releases
    releases ||= project.unreleased_releases + [:unassigned]
    releases = [*releases]

    issues = project.issues.inject({}) do |h, i|
      r = project.release_for(i.release) || :unassigned
      if i.claimed? && (opts[:all] || i.open?) && releases.member?(r)
        (h[i.claimer] ||= []) << i
      end
      h
    end

    if issues.empty?
      puts "No issues."
    else
      issues.keys.sort.each do |c|
        puts "#{c}:"
        puts todo_list_for(issues[c], :show_release => true)
        puts
      end
    end
  end

  operation :unclaimed, "Show all unclaimed issues", :maybe_release do
    opt :all, "Show all issues, not just open ones"
  end
  def unclaimed project, config, opts, releases
    releases ||= project.unreleased_releases + [:unassigned]
    releases = [*releases]

    issues = project.issues.select do |i|
      r = project.release_for(i.release) || :unassigned
      releases.member?(r) && i.claimer.nil? && (opts[:all] || i.open?)
    end
    if issues.empty?
      puts "No issues."
    else
      print_todo_list_by_release_for project, issues
    end
  end
end

end
