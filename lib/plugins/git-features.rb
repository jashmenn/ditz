require 'time'

module Ditz
class Issue
  field :git_branch, :ask => false

  def git_commits
    return @git_commits if @git_commits

    filters = ["--grep=\"Ditz-issue: #{id}\""]
    filters << "master..#{git_branch}" if git_branch

    output = filters.map do |f|
      `git log --pretty=format:\"%aD\t%an <%ae>\t%h\t%s\" #{f}`
    end.join

    @git_commits = output.split(/\n/).map { |l| l.split("\t") }.
      map { |date, email, hash, msg| [Time.parse(date).utc, email, hash, msg] }
  end
end

class Config
  field :git_commit_url_prefix, :prompt => "URL prefix (if any) to link git commits to"
  field :git_branch_url_prefix, :prompt => "URL prefix (if any) to link git branches to"
end

class ScreenView
  add_to_view :issue_summary do |issue, config|
    " Git branch: #{issue.git_branch || 'none'}\n"
  end

  add_to_view :issue_details do |issue, config|
    commits = issue.git_commits[0...5]
    next if commits.empty?
    "Recent commits:\n" + commits.map do |date, email, hash, msg|
      "- #{msg} [#{hash}] (#{email}; #{date.ago} ago)\n"
     end.join + "\n"
  end
end

class HtmlView
  add_to_view :issue_summary do |issue, config|
    next unless issue.git_branch
    [<<EOS, { :issue => issue, :url_prefix => config.git_branch_url_prefix }]
<tr>
  <td class='attrname'>Git branch:</td>
  <td class='attrval'><%= url_prefix ? link_to([url_prefix, issue.git_branch].join, issue.git_branch) : h(issue.git_branch) %></td>
</tr>
EOS
  end

  add_to_view :issue_details do |issue, config|
    commits = issue.git_commits
    next if commits.empty?

    [<<EOS, { :commits => commits, :url_prefix => config.git_commit_url_prefix }]
<h2>Commits for this issue</h2>
<table>
<% commits.each_with_index do |(time, who, hash, msg), i| %>
<% if i % 2 == 0 %>
  <tr class="logentryeven">
<% else %>
  <tr class="logentryodd">
<% end %>
  <td class="logtime"><%=t time %></td>
  <td class="logwho"><%=obscured_email who %></td>
  <td class="logwhat"><%=h msg %> [<%= url_prefix ? link_to([url_prefix, hash].join, hash) : hash %>]</td>
  </tr>
<% end %>
</table>
EOS
  end
end

class Operator
  operation :set_branch, "Set the git feature branch of an issue", :issue, :maybe_string
  def set_branch project, config, issue, maybe_string
    puts "Issue #{issue.name} currently " + if issue.git_branch
      "assigned to git branch #{issue.git_branch.inspect}."
    else
      "not assigned to any git branch."
    end

    branch = maybe_string || ask("Git feature branch name:")
    return unless branch

    if branch == issue.git_branch
      raise Error, "issue #{issue.name} already assigned to branch #{issue.git_branch.inspect}"
    end

    puts "Assigning to branch #{branch.inspect}."
    issue.git_branch = branch
  end

  operation :commit, "Runs git-commit and auto-fills the issue name in the commit message", :issue
  def commit project, config, issue
    exec "git commit -v -m \"Ditz-issue: #{issue.id}\" -e"
  end
end

end
