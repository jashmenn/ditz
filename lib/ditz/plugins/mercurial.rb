## mercurial ditz plugin
##
## This plugin allows ditz issues to be associated with mercurial commits
## It is currently lacking adequate developer documentation, but we are looking forward to somene helping out as soon as possible with this.
## Usage: 
##   1. add a line "- mercurial" to the .ditz-plugins file in the
##   project root
require 'time'

module Ditz
  class Issue
    def hg_commits
      return @hg_commits if @hg_commits
      output = `hg log --template '{date|rfc822date}\t{author}\t{node|short}\t{desc|firstline}\n' --keyword '#{id}'`

      @hg_commits = output.split("\n").map {|line|
        date, *vals = line.split("\t")
        [Time.parse(date), *vals]
      }
    end
  end

  class Config
    field :mercurial_commit_url_prefix, :prompt => "URL prefix (if any) to link mercurial commits to"
  end

  class ScreenView
    add_to_view :issue_details do |issue, config|
      next if (commits = issue.hg_commits[0...5]).empty?

      commits.map {|date, author, node, desc|
        "- #{desc} [#{node}] (#{author.shortened_email}, #{date.ago} ago)"
      }.unshift('Recent commits:').join("\n") + "\n"
    end
  end

  class HtmlView
    add_to_view :issue_details do |issue, config|
      next if (commits = issue.hg_commits).empty?

      [<<-EOS, {:commits => commits, :url_prefix => config.mercurial_commit_url_prefix}]
<h2>Commits for this issue</h2>
<table>
<% commits.each_with_index do |(date, author, node, desc), i| %>
  <tr class="logentry<%= i.even? ? 'even' : 'odd' %>">
  <td class="logtime"><%=t date %></td>
  <td class="logwho"><%=obscured_email author %></td>
  <td class="logwhat"><%=h desc %> [<%= url_prefix ? link_to([url_prefix, node].join, node) : node %>]</td>
  </tr>
<% end %>
</table>
      EOS
    end
  end
end
