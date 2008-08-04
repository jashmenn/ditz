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
    next unless issue.git_branch
    [<<EOS, { :issue => issue, :url_prefix => config.git_branch_url_prefix }]
<tr>
  <td class='attrname'>Claimed by:</td>
  <td class='attrval'>h(issue.claimer) %></td>
</tr>
EOS
  end
end

class Operator
  operation :claim, "Claim an issue for yourself", :issue do
    opt :force, "Claim this issue even if someone else has claimed it", :default => false
  end
  def claim project, config, opts, issue
    puts "Claiming issue #{issue.name}: #{issue.title}."
    comment = ask_multiline "Comments" unless $opts[:no_comment]
    issue.claim config.user, comment, opts[:force]
    puts "Issue #{issue.name} marked as claimed by #{config.user}"
  end

  operation :unclaim, "Unclaim a claimed issue", :issue do
    opt :force, "Unclaim this issue even if it's claimed by someone else", :default => false
  end
  def unclaim project, config, opts, issue
    puts "Unclaiming issue #{issue.name}: #{issue.title}."
    comment = ask_multiline "Comments" unless $opts[:no_comment]
    issue.unclaim config.user, comment, opts[:force]
    puts "Issue #{issue.name} marked as unclaimed."
  end

  operation :claimed, "Show all issues claimed by you" do
    opt :all, "Show all issues, not just open ones"
  end
  def claimed project, config, opts
    puts "#{opts[:all] ? "All" : "Open"} issues claimed by you:"
    issues = project.issues.select { |i| i.claimer == config.user && (opts[:all] || i.open?) }
    if issues.empty?
      puts "No issues."
    else
      print_todo_list_by_release_for project, issues
    end
  end

  operation :unclaimed, "Show all unclaimed issues" do
    opt :all, "Show all issues, not just open ones"
  end
  def unclaimed project, config, opts
    puts "Unclaimed#{opts[:all] ? "" : ", open"} issues:"
    issues = project.issues.select { |i| i.claimer.nil? && (opts[:all] || i.open?) }
    if issues.empty?
      puts "No issues."
    else
      print_todo_list_by_release_for project, issues
    end
  end
end

end
