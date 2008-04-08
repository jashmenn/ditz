require 'tempfile'
require 'fileutils'

require "html"

module Ditz

class Operator
  class Error < StandardError; end

  class << self
    def method_to_op meth; meth.to_s.gsub("_", "-") end
    def op_to_method op; op.gsub("-", "_").intern end

    def operation method, desc, *args_spec
      @operations ||= {}
      @operations[method] = { :desc => desc, :args_spec => args_spec }
    end

    def operations
      @operations.map { |k, v| [method_to_op(k), v] }.sort_by { |k, v| k }
    end
    def has_operation? op; @operations.member? op_to_method(op) end

    def parse_releases_arg project, releases_arg
      ret = []

      releases, show_unassigned, force_show = case releases_arg
        when nil; [project.releases, true, false]
        when "unassigned"; [[], true, true]
        else
          release = project.release_for(releases_arg)
          raise Error, "no release with name #{releases_arg}" unless release
          [[release], false, true]
        end

      releases.each do |r|
        next if r.released? unless force_show

        bugs = project.issues.
          select { |i| i.type == :bugfix && i.release == r.name }
        feats = project.issues.
          select { |i| i.type == :feature && i.release == r.name }

        #next if bugs.empty? && feats.empty? unless force_show

        ret << [r, bugs, feats]
      end

      return ret unless show_unassigned

      bugs = project.issues.select { |i| i.type == :bugfix && i.release.nil? }
      feats = project.issues.select { |i| i.type == :feature && i.release.nil? }

      return ret if bugs.empty? && feats.empty? unless force_show
      ret << [nil, bugs, feats]
    end
    private :parse_releases_arg

    def build_args project, method, args
      command = "command '#{method_to_op method}'"
      built_args = @operations[method][:args_spec].map do |spec|
        val = args.shift
        case spec
        when :issue
          raise Error, "#{command} requires an issue name" unless val
          project.issue_for(val) or raise Error, "no issue with name #{val}"
        when :release
          raise Error, "#{command} requires a release name" unless val
          project.release_for(val) or raise Error, "no release with name #{val}"
        when :maybe_release
          parse_releases_arg project, val
        when :string
          raise Error, "#{command} requires a string" unless val
          val
        else
          val # no translation for other types
        end
      end
      raise Error, "too many arguments for #{command}" unless args.empty?
      built_args
    end
  end

  def do op, project, config, args
    meth = self.class.op_to_method(op)
    built_args = self.class.build_args project, meth, args
    send meth, project, config, *built_args
  end

  %w(operations has_operation?).each do |m|
    define_method(m) { |*a| self.class.send m, *a }
  end

  operation :init, "Initialize the issue database for a new project"
  def init
    Project.create_interactively
  end

  operation :help, "List all registered commands"
  def help
    puts <<EOS
Ditz commands:
EOS
    ops = self.class.operations
    args = ops.map do |name, op|
      op[:args_spec].map do |spec|
        case spec.to_s
        when /^maybe_(.*)$/
          "[#{$1}]"
        else
          "<#{spec.to_s}>"
        end
      end.join(" ")
    end
    len_name = ops.map { |name, op| name.to_s.length }.max
    len_args = args.map { |name, op| name.to_s.length }.max
    ops.zip(args).each do |(name, op), args|
      printf "%#{len_name}s %-#{len_args}s: %s\n", name, args, op[:desc]
    end
    puts
  end

  operation :add, "Add a bug/feature request"
  def add project, config
    issue = Issue.create_interactively(:args => [config, project]) or return
    comment = ask_multiline "Comments"
    issue.log "created", config.user, comment
    project.add_issue issue
    project.assign_issue_names!
    puts "Added issue #{issue.name}."
  end

  operation :drop, "Drop a bug/feature request", :issue
  def drop project, config, issue
    project.drop_issue issue
    puts "Dropped #{issue.name}. Note that other issue names may have changed."
  end

  operation :add_release, "Add a release"
  def add_release project, config
    release = Release.create_interactively(:args => [project, config]) or return
    comment = ask_multiline "Comments"
    release.log "created", config.user, comment
    project.add_release release
    puts "Added release #{release.name}."
  end

  operation :add_component, "Add a component"
  def add_component project, config
    component = Component.create_interactively(:args => [project, config]) or return
    project.add_component component
    puts "Added component #{component.name}."
  end

  operation :add_reference, "Add a reference to an issue", :issue
  def add_reference project, config, issue
    puts "Adding a reference to #{issue.name}: #{issue.title}."
    reference = ask "Reference"
    comment = ask_multiline "Comments"
    issue.add_reference reference
    issue.log "added reference #{issue.references.size}", config.user, comment
    puts "Added reference to #{issue.name}."
  end

  operation :status, "Show project status", :maybe_release
  def status project, config, releases
    releases.each do |r, bugs, feats|
      title, bar = [r ? r.name : "unassigned", status_bar_for(bugs + feats)]

      ncbugs = bugs.count_of { |b| b.closed? }
      ncfeats = feats.count_of { |f| f.closed? }
      pcbugs = 100.0 * (bugs.empty? ? 1.0 : ncbugs.to_f / bugs.size)
      pcfeats = 100.0 * (feats.empty? ? 1.0 : ncfeats.to_f / feats.size)

      special = if r && r.released?
        "(released)"
      elsif bugs.empty? && feats.empty?
        "(no issues)"
      elsif ncbugs == bugs.size && ncfeats == feats.size
        "(ready for release)"
      else
        bar
      end

      printf "%-10s %2d/%2d (%3.0f%%) bugs, %2d/%2d (%3.0f%%) features %s\n",
        title, ncbugs, bugs.size, pcbugs, ncfeats, feats.size, pcfeats, special
    end

    if project.releases.empty?
      puts "No releases."
      return
    end
  end

  def status_bar_for issues
    Issue::STATUS_WIDGET.
      sort_by { |k, v| -Issue::STATUS_SORT_ORDER[k] }.
      map { |k, v| v * issues.count_of { |i| i.status == k } }.
      join
  end

  def todo_list_for issues
    return if issues.empty?
    name_len = issues.max_of { |i| i.name.length }
    issues.map do |i|
      sprintf "%s %#{name_len}s: %s\n", i.status_widget, i.name, i.title
    end.join
  end

  operation :todo, "Generate todo list", :maybe_release
  def todo project, config, releases
    actually_do_todo project, config, releases, false
  end

  operation :todo_full, "Generate full todo list, including completed items", :maybe_release
  def todo_full project, config, releases
    actually_do_todo project, config, releases, true
  end

  def actually_do_todo project, config, releases, full
    releases.each do |r, bugs, feats|
      if r
        puts "Version #{r.name} (#{r.status}):"
      else
        puts "Unassigned:"
      end
      issues = bugs + feats
      issues = issues.select { |i| i.open? } unless full
      puts(todo_list_for(issues.sort_by { |i| i.sort_order }) || "No open issues.")
      puts
    end
  end

  operation :show, "Describe a single issue", :issue
  def show project, config, issue
    status = case issue.status
    when :closed
      "#{issue.status_string}: #{issue.disposition_string}"
    else
      issue.status_string
    end
    puts <<EOS
#{"Issue #{issue.name}".underline}
      Title: #{issue.title}
Description: #{issue.interpolated_desc(project.issues).multiline "  "}
       Type: #{issue.type}
     Status: #{status}
    Creator: #{issue.reporter}
        Age: #{issue.creation_time.ago}
    Release: #{issue.release}
 References: #{issue.references.listify "  "}
 Identifier: #{issue.id}

Event log:
#{format_log_events issue.log_events}
EOS
  end

  def format_log_events events
    return "none" if events.empty?
    events.map do |time, who, what, comment|
      "- #{time.pretty} :: #{who}\n  #{what}#{comment.multiline "  > "}"
    end.join("\n")
  end

  operation :start, "Start work on an issue", :issue
  def start project, config, issue
    puts "Starting work on issue #{issue.name}: #{issue.title}."
    comment = ask_multiline "Comments"
    issue.start_work config.user, comment
    puts "Recorded start of work for #{issue.name}."
  end

  operation :stop, "Stop work on an issue", :issue
  def stop project, config, issue
    puts "Stopping work on issue #{issue.name}: #{issue.title}."
    comment = ask_multiline "Comments"
    issue.stop_work config.user, comment
    puts "Recorded work stop for #{issue.name}."
  end

  operation :close, "Close an issue", :issue
  def close project, config, issue
    puts "Closing issue #{issue.name}: #{issue.title}."
    disp = ask_for_selection Issue::DISPOSITIONS, "disposition", lambda { |x| Issue::DISPOSITION_STRINGS[x] || x.to_s }
    comment = ask_multiline "Comments"
    issue.close disp, config.user, comment
    puts "Closed issue #{issue.name} with disposition #{issue.disposition_string}."
  end

  operation :assign, "Assign an issue to a release", :issue
  def assign project, config, issue
    puts "Issue #{issue.name} currently " + if issue.release
      "assigned to release #{issue.release}."
    else
      "not assigned to any release."
    end
    release = ask_for_selection project.releases, "release", :name
    comment = ask_multiline "Comments"
    issue.assign_to_release release, config.user, comment
    puts "Assigned #{issue.name} to #{release.name}."
  end

  operation :unassign, "Unassign an issue from any releases", :issue
  def unassign project, config, issue
    puts "Unassigning issue #{issue.name}: #{issue.title}."
    comment = ask_multiline "Comments"
    issue.unassign config.user, comment
    puts "Unassigned #{issue.name}."
  end

  operation :comment, "Comment on an issue", :issue
  def comment project, config, issue
    puts "Commenting on issue #{issue.name}: #{issue.title}."
    comment = ask_multiline "Comments"
    issue.log "commented", config.user, comment
    puts "Comments recorded for #{issue.name}."
  end

  operation :releases, "Show releases"
  def releases project, config
    a, b = project.releases.partition { |r| r.released? }
    (b + a.sort_by { |r| r.release_time }).each do |r|
      status = r.released? ? "released #{r.release_time.pretty_date}" : r.status
      puts "#{r.name} (#{status})"
    end
  end

  operation :release, "Release a release", :release
  def release project, config, release
    comment = ask_multiline "Comments"
    release.release! project, config.user, comment
    puts "Release #{release.name} released!"
  end

  operation :changelog, "Generate a changelog for a release", :release
  def changelog project, config, r
    feats, bugs = project.issues_for_release(r).partition { |i| i.feature? }
    puts "== #{r.name} / #{r.released? ? r.release_time.pretty_date : 'unreleased'}"
    feats.select { |f| f.closed? }.each { |i| puts "* #{i.title}" }
    bugs.select { |f| f.closed? }.each { |i| puts "* bugfix: #{i.title}" }
  end

  operation :html, "Generate html status pages", :dir
  def html project, config, dir
    #FileUtils.rm_rf dir
    dir ||= "html"
    Dir.mkdir dir unless File.exists? dir

    ## find the ERB templates. this is my brilliant approach
    ## to the 'gem datadir' problem.
    template_dir = $:.find { |p| File.exists? File.join(p, "index.rhtml") }

    FileUtils.cp File.join(template_dir, "style.css"), dir

    ## build up links
    links = {}
    project.releases.each { |r| links[r] = "release-#{r.name}.html" }
    project.issues.each { |i| links[i] = "issue-#{i.id}.html" }
    project.components.each { |c| links[c] = "component-#{c.name}.html" }
    links["unassigned"] = "unassigned.html" # special case: unassigned
    links["index"] = "index.html" # special case: index

    project.issues.each do |issue|
      fn = File.join dir, links[issue]
      puts "Generating #{fn}..."
      File.open(fn, "w") do |f|
        f.puts ErbHtml.new(template_dir, "issue", links, :issue => issue,
          :release => (issue.release ? project.release_for(issue.release) : nil),
          :component => project.component_for(issue.component),
          :project => project)
      end
    end

    project.releases.each do |r|
      fn = File.join dir, links[r]
      puts "Generating #{fn}..."
      File.open(fn, "w") do |f|
        f.puts ErbHtml.new(template_dir, "release", links, :release => r,
          :issues => project.issues_for_release(r), :project => project)
      end
    end

    project.components.each do |c|
      fn = File.join dir, links[c]
      puts "Generating #{fn}..."
      File.open(fn, "w") do |f|
        f.puts ErbHtml.new(template_dir, "component", links, :component => c,
          :issues => project.issues_for_component(c), :project => project)
      end
    end

    fn = File.join dir, links["unassigned"]
    puts "Generating #{fn}..."
    File.open(fn, "w") do |f|
      f.puts ErbHtml.new(template_dir, "unassigned", links,
        :issues => project.unassigned_issues, :project => project)
    end

    past_rels, upcoming_rels = project.releases.partition { |r| r.released? }
    fn = File.join dir, links["index"]
    puts "Generating #{fn}..."
    File.open(fn, "w") do |f|
      f.puts ErbHtml.new(template_dir, "index", links, :project => project,
        :past_releases => past_rels, :upcoming_releases => upcoming_rels,
        :components => project.components)
    end
    puts "You can browse the generated pages at: file://#{File.expand_path(fn)}"
  end

  operation :validate, "Validate project status"
  def validate project, config
    ## a no-op
  end

  operation :grep, "Show issues matching a string or regular expression", :string
  def grep project, config, match
    re = /#{match}/
    issues = project.issues.select { |i| i.title =~ re || i.desc =~ re }
    puts(todo_list_for(issues) || "No matching issues.")
  end

  operation :edit, "Edit an issue", :issue
  def edit project, config, issue
    data = { :title => issue.title, :description => issue.desc,
             :reporter => issue.reporter }

    f = Tempfile.new("ditz")
    f.puts data.to_yaml
    f.close
    editor = ENV["EDITOR"] || "/usr/bin/vi"
    cmd = "#{editor} #{f.path.inspect}"
    Ditz::debug "running: #{cmd}"

    mtime = File.mtime f.path
    system cmd or raise Error, "cannot execute command: #{cmd.inspect}"
    if File.mtime(f.path) == mtime
      puts "Aborted."
      return
    end

    comment = ask_multiline "Comments"
    begin
      edits = YAML.load_file f.path
      if issue.change edits, config.user, comment
        puts "Changed recorded."
      else
        puts "No changes."
      end
    end
  end
end

end
