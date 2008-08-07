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
  field :git_commit_url_prefix, :prompt => "URL prefix to link git commits to", :default => ""
  field :git_branch_url_prefix, :prompt => "URL prefix to link git branches to", :default => ""
end

class ScreenView
  add_to_view :issue_summary do |issue, config|
    " Git branch: #{issue.git_branch || 'none'}\n"
  end

  add_to_view :issue_details do |issue, config|
    commits = issue.git_commits[0...5]
    next if commits.empty?
    "Recent commits:\n" + commits.map do |date, email, hash, msg|
      "- #{msg} [#{hash}] (#{email.shortened_email}, #{date.ago} ago)\n"
     end.join + "\n"
  end
end

class HtmlView
  add_to_view :issue_summary do |issue, config|
    next unless issue.git_branch
    [<<EOS, { :issue => issue, :url_prefix => config.git_branch_url_prefix }]
<tr>
  <td class='attrname'>Git branch:</td>
  <td class='attrval'><%= url_prefix && !url_prefix.blank? ? link_to([url_prefix, issue.git_branch].join, issue.git_branch) : h(issue.git_branch) %></td>
</tr>
EOS
  end

  add_to_view :issue_details do |issue, config|
    commits = issue.git_commits
    next if commits.empty?

    [<<EOS, { :commits => commits, :url_prefix => config.git_commit_url_prefix }]
<h2>Commits for this issue</h2>
<table class="log">
<% commits.each_with_index do |(time, who, hash, msg), i| %>
  <tr class="<%= i % 2 == 0 ? "even-row" : "odd-row" %>">
  <td class="time"><%=t time %></td>
  <td class="person"><%=obscured_email who %></td>
  <td class="message"><%=h msg %> [<%= url_prefix && !url_prefix.blank? ? link_to([url_prefix, hash].join, hash) : hash %>]</td>
  </tr>
  <tr><td></td></tr>
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

  operation :commit, "Runs git-commit and auto-fills the issue name in the commit message", :issue do
    opt :all, "commit all changed files", :short => "-a", :default => false
    opt :verbose, "show diff between HEAD and what would be committed", \
      :short => "-v", :default => false
    opt :message, "Use the given <s> as the commit message.", \
      :short => "-m", :type => :string
    opt :edit, "Further edit the message, even if --message is given.", :short => "-e", :default => false
  end

  def commit project, config, opts, issue
    opts[:edit] = true if opts[:message].nil?

    args = {
      :verbose => "--verbose",
      :all => "--all",
      :edit => "--edit",
    }.map { |k, v| opts[k] ? v : "" }.join(" ")

    comment = "# #{issue.name}: #{issue.title}"
    tag = "Ditz-issue: #{issue.id}"
    message = if opts[:message] && !opts[:edit]
      "#{opts[:message]}\n\n#{tag}"
    elsif opts[:message] && opts[:edit]
      "#{opts[:message]}\n\n#{comment}\n#{tag}"
    else
      "#{comment}\n#{tag}"
    end
    exec "git commit #{args} --message=\"#{message}\""
  end
end

end
