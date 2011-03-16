require "ditz/view"
require "ditz/html"
require 'time'

module Ditz

class ScreenView < View
  def initialize project, config, device=$stdout
    @device = device
    @config = config
  end

  def format_log_events events
    return "none" if events.empty?
    events.reverse.map do |time, who, what, comment|
      "- #{what} (#{who.shortened_email}, #{time.ago} ago)" +
      (comment =~ /\S/ ? "\n" + comment.gsub(/^/, "  > ") : "")
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
    desc = if issue.desc.size < 80 - "Description: ".length
      issue.desc
    else
      "\n" + issue.desc.gsub(/^/, "  ") + "\n"
    end
    run_pager @config
    @device.puts <<EOS
#{"Issue #{issue.name}".underline}
      Title: #{issue.title}
Description: #{desc}
       Type: #{issue.type}
     Status: #{status}
    Creator: #{issue.reporter}
        Age: #{issue.creation_time.ago}
    Release: #{issue.release}
 References: #{issue.references.listify "  "}
 Identifier: #{issue.id}
EOS

    self.class.view_additions_for(:issue_summary).each { |b| @device.print(b[issue, @config] || next) }
    puts
    self.class.view_additions_for(:issue_details).each { |b| @device.print(b[issue, @config] || next)  }

    @device.puts <<EOS
Event log:
#{format_log_events issue.log_events}
EOS
  end
end

class HtmlView < View
  SUPPORT_FILES = %w(style.css blue-check.png red-check.png green-check.png green-bar.png yellow-bar.png)

  def initialize project, config, dir
    @project = project
    @config = config
    @dir = dir
    @template_dir = File.dirname Ditz::find_ditz_file("../share/ditz/index.rhtml")
  end

  def render_all
    Dir.mkdir @dir unless File.exists? @dir
    SUPPORT_FILES.each { |f| FileUtils.cp File.join(@template_dir, f), @dir }

    ## build up links
    links = {}
    @project.releases.each { |r| links[r] = "release-#{r.name}.html" }
    @project.issues.each { |i| links[i] = "issue-#{i.id}.html" }
    @project.components.each { |c| links[c] = "component-#{c.name}.html" }
    links["unassigned"] = "unassigned.html" # special case: unassigned
    links["index"] = "index.html" # special case: index
    links["feed"]= "feed.xml" # special case: feed

    @project.issues.each do |issue|
      fn = File.join @dir, links[issue]
      #puts "Generating #{fn}..."

      extra_summary = self.class.view_additions_for(:issue_summary).map { |b| b[issue, @config] }.compact
      extra_details = self.class.view_additions_for(:issue_details).map { |b| b[issue, @config] }.compact

      erb = ErbHtml.new(@template_dir, links, :issue => issue,
        :release => (issue.release ? @project.release_for(issue.release) : nil),
        :component => @project.component_for(issue.component),
        :project => @project)

      extra_summary_html = extra_summary.map { |string, extra_binding| erb.render_string string, extra_binding }.join
      extra_details_html = extra_details.map { |string, extra_binding| erb.render_string string, extra_binding }.join

      File.open(fn, "w") { |f| f.puts erb.render_template("issue", { :extra_summary_html => extra_summary_html, :extra_details_html => extra_details_html }) }
    end

    @project.releases.each do |r|
      fn = File.join @dir, links[r]
      #puts "Generating #{fn}..."
      File.open(fn, "w") do |f|
        f.puts ErbHtml.new(@template_dir, links, :release => r,
          :issues => @project.issues_for_release(r), :project => @project).
          render_template("release")
      end
    end

    @project.components.each do |c|
      fn = File.join @dir, links[c]
      #puts "Generating #{fn}..."
      File.open(fn, "w") do |f|
        f.puts ErbHtml.new(@template_dir, links, :component => c,
          :issues => @project.issues_for_component(c), :project => @project).
          render_template("component")
      end
    end

    fn = File.join @dir, links["unassigned"]
    #puts "Generating #{fn}..."
    File.open(fn, "w") do |f|
      f.puts ErbHtml.new(@template_dir, links,
        :issues => @project.unassigned_issues, :project => @project).
        render_template("unassigned")
    end
    fn = File.join @dir, links["feed"]
    #puts "Generating #{fn}..."
    File.open(fn, "w") do |f|
      f.puts ErbHtml.new(@template_dir, links, :project => @project).
        render_template("feed")
    end

    past_rels, upcoming_rels = @project.releases.partition { |r| r.released? }
    fn = File.join @dir, links["index"]
    #puts "Generating #{fn}..."
    File.open(fn, "w") do |f|
      f.puts ErbHtml.new(@template_dir, links, :project => @project,
        :past_releases => past_rels, :upcoming_releases => upcoming_rels,
        :components => @project.components).
        render_template("index")
    end
    puts "Local generated URL: file://#{File.expand_path(fn)}"
  end
end

class BaetleView < View
  def initialize project, config, dir
    @project = project
    @config = config
    @dir = dir
  end
  
  def render_all
    Dir.mkdir @dir unless File.exists? @dir
    fn = File.join @dir, "baetle.rdf"
    File.open(fn, "w") { |f| 
        f.puts <<EOS
@prefix baetle: <http://xmlns.com/baetle/#> .
@prefix wf: <http://www.w3.org/2005/01/wf/flow#> .
@prefix sioc: <http://rdfs.org/sioc/ns#> .
@prefix dc: <http://purl.org/dc/elements/1.1/> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#>.
@prefix : <#> .

EOS
        @project.issues.each do |issue|
          # id
          f.print ":#{issue.id} a "
          f.print case issue.type 
                when :bugfix, :bug: "baetle:Bug"
                when :feature: "baetle:Enhancement"
                when :task: "wf:Task"
                end
          f.puts " ;"
          # title
          f.puts "    baetle:title #{issue.title.dump} ;"
          # summary
          f.puts "    baetle:description #{issue.desc.dump} ; "
          # state
          f.print "    wf:state baetle:" 
          f.print case issue.status
                  when :unstarted: "New"
                  when :in_progress: "Started"
                  when :closed: "Closed"
                  when :paused: "Later"
                  end
          f.puts " ;"
          # created
          f.puts "    baetle:created #{issue.creation_time.xmlschema.dump}^^xsd:dateTime ."
          f.puts
        end
      }
    puts "Local generated URL: file://#{File.expand_path(fn)}"
  end
end

end
