require 'view'
require 'html'

module Ditz

class ScreenView < View
  def initialize project, config, device=$stdout
    @device = device
  end

  def format_log_events events
    return "none" if events.empty?
    events.map do |time, who, what, comment|
      "- #{time.pretty} :: #{who}\n  #{what}#{comment.multiline "  > "}"
    end.join("\n")
  end
  private :format_log_events

  def render_issue issue
    status = case issue.status
    when :closed
      "#{issue.status_string}: #{issue.disposition_string}"
    else
      issue.status_string
    end
    @device.puts <<EOS
#{"Issue #{issue.name}".underline}
      Title: #{issue.title}
Description: #{issue.desc.multiline "  "}
       Type: #{issue.type}
     Status: #{status}
    Creator: #{issue.reporter}
        Age: #{issue.creation_time.ago}
    Release: #{issue.release}
 References: #{issue.references.listify "  "}
 Identifier: #{issue.id}
EOS

    self.class.view_additions_for(:issue_summary).each { |b| puts b[issue] }

    puts

    self.class.view_additions_for(:issue_details).each do |b|
      print b[issue]
    end

@device.puts <<EOS
Event log:
#{format_log_events issue.log_events}
EOS
  end
end

class HtmlView < View
  def initialize project, config, dir
    @dir = dir
    @project = project
    @template_dir = File.dirname find_ditz_file("index.rhtml")
  end

  def render_all
    Dir.mkdir @dir unless File.exists? @dir
    FileUtils.cp File.join(@template_dir, "style.css"), @dir

    ## build up links
    links = {}
    @project.releases.each { |r| links[r] = "release-#{r.name}.html" }
    @project.issues.each { |i| links[i] = "issue-#{i.id}.html" }
    @project.components.each { |c| links[c] = "component-#{c.name}.html" }
    links["unassigned"] = "unassigned.html" # special case: unassigned
    links["index"] = "index.html" # special case: index

    @project.issues.each do |issue|
      fn = File.join @dir, links[issue]
      #puts "Generating #{fn}..."

      extra_summary = self.class.view_additions_for(:issue_summary).map { |b| b[issue] }
      extra_details = self.class.view_additions_for(:issue_details).map { |b| b[issue] }
      File.open(fn, "w") do |f|
        f.puts ErbHtml.new(@template_dir, "issue", links, :issue => issue,
          :release => (issue.release ? @project.release_for(issue.release) : nil),
          :component => @project.component_for(issue.component),
          :extra_summary => extra_summary,
          :extra_details => extra_details,
          :project => @project)
      end
    end

    @project.releases.each do |r|
      fn = File.join @dir, links[r]
      #puts "Generating #{fn}..."
      File.open(fn, "w") do |f|
        f.puts ErbHtml.new(@template_dir, "release", links, :release => r,
          :issues => @project.issues_for_release(r), :project => @project)
      end
    end

    @project.components.each do |c|
      fn = File.join @dir, links[c]
      #puts "Generating #{fn}..."
      File.open(fn, "w") do |f|
        f.puts ErbHtml.new(@template_dir, "component", links, :component => c,
          :issues => @project.issues_for_component(c), :project => @project)
      end
    end

    fn = File.join @dir, links["unassigned"]
    #puts "Generating #{fn}..."
    File.open(fn, "w") do |f|
      f.puts ErbHtml.new(@template_dir, "unassigned", links,
        :issues => @project.unassigned_issues, :project => @project)
    end

    past_rels, upcoming_rels = @project.releases.partition { |r| r.released? }
    fn = File.join @dir, links["index"]
    #puts "Generating #{fn}..."
    File.open(fn, "w") do |f|
      f.puts ErbHtml.new(@template_dir, "index", links, :project => @project,
        :past_releases => past_rels, :upcoming_releases => upcoming_rels,
        :components => @project.components)
    end
    puts "Local generated URL: file://#{File.expand_path(fn)}"
  end
end

end
