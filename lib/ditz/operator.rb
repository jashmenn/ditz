require 'fileutils'

module Ditz

class Operator
  class Error < StandardError; end

  class << self
    def method_to_op meth; meth.to_s.gsub("_", "-") end
    def op_to_method op; op.gsub("-", "_").intern end

    def operation method, desc, *args_spec, &options_blk
      @operations ||= {}
      @operations[method] = { :desc => desc, :args_spec => args_spec,
                              :options_blk => options_blk }
    end

    def operations
      @operations.map { |k, v| [method_to_op(k), v] }.sort_by { |k, v| k }
    end
    def has_operation? op; @operations.member? op_to_method(op) end

    def build_opts method, args
      options_blk = @operations[method][:options_blk]
      options_blk and options args, &options_blk or nil
    end

    ## parse the specs, and the commandline arguments, and resolve them. does
    ## typechecking but currently doesn't check for open_issues actually being
    ## open, unstarted_issues being unstarted, etc. probably will check for
    ## this in the future.
    def build_args project, method, args
      specs = @operations[method][:args_spec]
      command = "command '#{method_to_op method}'"

      if specs.empty? && args == ["<options>"]
        die_with_completions project, method, nil
      end

      built_args = specs.map do |spec|
        optional = spec.to_s =~ /^maybe_/
        spec = spec.to_s.gsub(/^maybe_/, "").intern # :(
        val = args.shift

        case val
        when nil
          next if optional
          specname = spec.to_s.gsub("_", " ")
          article = specname =~ /^[aeiou]/ ? "an" : "a"
          raise Error, "#{command} requires #{article} #{specname}"
        when "<options>"
          die_with_completions project, method, spec
        end

        case spec
        when :issue, :open_issue, :unstarted_issue, :started_issue, :assigned_issue
          ## issue completion sticks the title on there, so this will strip it off
          valr = val.sub(/\A(\w+-\d+)_.*$/,'\1')
          issues = project.issues_for valr
          case issues.size
          when 0; raise Error, "no issue with name #{val.inspect}"
          when 1; issues.first
          else
            raise Error, "multiple issues matching name #{val.inspect}"
          end
        when :release, :unreleased_release
          if val == "unassigned"
            :unassigned
          else
            project.release_for(val) or raise Error, "no release with name #{val}"
          end
        when :component
          project.component_for(val) or raise Error, "no component with name #{val}" if val
        else
          val # no translation for other types
        end
      end

      raise Error, "too many arguments for #{command}" unless args.empty?
      built_args
    end

    def die_with_completions project, method, spec
      puts(case spec
      when :issue, :open_issue, :unstarted_issue, :started_issue, :assigned_issue
        m = { :issue => nil,
              :open_issue => :open?,
              :unstarted_issue => :unstarted?,
              :started_issue => :in_progress?,
              :assigned_issue => :assigned?,
            }[spec]
        project.issues.select { |i| m.nil? || i.send(m) }.sort_by { |i| i.creation_time }.reverse.map { |i| "#{i.name}_#{i.title.gsub(/\W+/, '-')}" }
      when :release
        project.releases.map { |r| r.name } + ["unassigned"]
      when :unreleased_release
        project.releases.select { |r| r.unreleased? }.map { |r| r.name }
      when :component
        project.components.map { |c| c.name }
      when :command
        operations.map { |name, _| name }
      else
        ""
      end)
      exit 0
    end
    private :die_with_completions
  end

  def do op, project, config, args
    meth = self.class.op_to_method(op)

    # Parse options, removing them from args
    opts = self.class.build_opts meth, args
    built_args = self.class.build_args project, meth, args

    built_args.unshift opts if opts

    send meth, project, config, *built_args
  end

  %w(operations has_operation?).each do |m|
    define_method(m) { |*a| self.class.send m, *a }
  end

  operation :init, "Initialize the issue database for a new project"
  def init
    Project.create_interactively
  end

  operation :help, "List all registered commands", :maybe_command do
    opt :cow, "Activate super cow powers", :default => false
  end
  def help project, config, opts, command
    if opts[:cow]
      puts "MOO!"
      puts "All is well with the world now. A bit more methane though."
      return
    end
    run_pager config
    return help_single(command) if command
    puts <<EOS
Ditz commands:

EOS
    ops = self.class.operations
    len = ops.map { |name, op| name.to_s.length }.max
    ops.each do |name, opts|
      printf "  %#{len}s: %s\n", name, opts[:desc]
    end
    puts <<EOS

Use 'ditz help <command>' for details.
EOS
  end

  def help_single command
    name, opts = self.class.operations.find { |name, spec| name == command }
    raise Error, "no such ditz command '#{command}'" unless name
    args = opts[:args_spec].map do |spec|
      case spec.to_s
      when /^maybe_(.*)$/
        "[#{$1}]"
      else
        "<#{spec.to_s}>"
      end
    end.join(" ")

    puts <<EOS
#{opts[:desc]}.
Usage: ditz #{name} #{args}
EOS
  end

  ## gets a comment from the user, assuming the standard argument setup
  def get_comment opts
    comment = if opts[:no_comment]
      nil
    elsif opts[:comment]
      opts[:comment]
    else
      ask_multiline_or_editor "Comments"
    end
  end
  private :get_comment

  operation :reconfigure, "Rerun configuration script"
  def reconfigure project, config
    new_config = Config.create_interactively :defaults_from => config
    new_config.save! $opts[:config_file]
    puts "Configuration written."
  end

  operation :add, "Add an issue" do
    opt :comment, "Specify a comment", :short => 'm', :type => String
    opt :quick, "Just one line issue", :short => 'q', :type => String
    opt :component, "Specify a component", :short => 'c', :type => String
    opt :release, "Specify a release", :short => 'r', :type => String
    opt :ask_for_comment, "Ask for a comment", :default => false
  end
  def add project, config, opts
    component = opts[:component] ||  project.components.first.name
    release = opts[:release] || project.releases.first.name
    with = if opts[:quick]
      {:title => opts[:quick], :desc => '', :type => :task, :component => component,
        :reporter => config.user, :release => release}
    end
    issue = Issue.create_interactively(:args => [config, project], :with => with)
    issue or return
    comment = if opts[:comment]
      opts[:comment]
    elsif opts[:ask_for_comment]
      ask_multiline_or_editor "Comments"
    end
    issue.log "created", config.user, comment
    project.add_issue issue
    project.assign_issue_names!
    puts "Added issue #{issue.name} (#{issue.id})."
  end

  operation :drop, "Drop an issue", :issue
  def drop project, config, issue
    project.drop_issue issue
    puts "Dropped #{issue.name}. Note that other issue names may have changed."
  end

  operation :drop_release, "Drop a release", :release
  def drop_release project, config, release
    project.drop_release release
    puts "Dropped release #{release.name}."
  end

  operation :add_release, "Add a release", :maybe_name do
    opt :comment, "Specify a comment", :short => 'm', :type => String
    opt :no_comment, "Skip asking for a comment", :default => false
  end
  def add_release project, config, opts, maybe_name
    puts "Adding release #{maybe_name}." if maybe_name
    release = Release.create_interactively(:args => [project, config], :with => { :name => maybe_name }) or return
    release.log "created", config.user, get_comment(opts)
    project.add_release release
    puts "Added release #{release.name}."
  end

  operation :add_component, "Add a component"
  def add_component project, config
    component = Component.create_interactively(:args => [project, config]) or return
    project.add_component component
    puts "Added component #{component.name}."
  end

  operation :add_reference, "Add a reference to an issue", :issue do
    opt :comment, "Specify a comment", :short => 'm', :type => String
    opt :no_comment, "Skip asking for a comment", :default => false
  end
  def add_reference project, config, opts, issue
    puts "Adding a reference to #{issue.name}: #{issue.title}."
    reference = ask "Reference"
    issue.add_reference reference
    issue.log "added reference #{issue.references.size}", config.user, get_comment(opts)
    puts "Added reference to #{issue.name}."
  end

  operation :status, "Show project status", :maybe_release
  def status project, config, releases
    run_pager config
    releases ||= project.unreleased_releases + [:unassigned]

    if releases.empty?
      puts "No releases."
      return
    end

    entries = releases.map do |r|
      title, issues = (r == :unassigned ? r.to_s : r.name), project.issues_for_release(r)

      middle = Issue::TYPES.map do |type|
        type_issues = issues.select { |i| i.type == type }
        num = type_issues.size
        nc = type_issues.count_of { |i| i.closed? }
        pc = 100.0 * (type_issues.empty? ? 1.0 : nc.to_f / num)
        "%2d/%2d %s" % [nc, num, type.to_s.pluralize(num, false)]
      end

      bar = if r == :unassigned
        ""
      elsif r.released?
        "(released)"
      elsif issues.empty?
        "(no issues)"
      elsif issues.all? { |i| i.closed? }
        "(ready for release)"
      else
        status_bar_for(issues)
      end

      [title, middle, bar]
    end

    title_size = 0
    middle_sizes = []

    entries.each do |title, middle, bar|
      title_size = [title_size, title.length].max
      middle_sizes = middle.zip(middle_sizes).map do |e, s|
        [s || 0, e.length].max
      end
    end

    entries.each do |title, middle, bar|
      printf "%-#{title_size}s ", title
      middle.zip(middle_sizes).each_with_index do |(e, s), i|
        sep = i < middle.size - 1 ? "," : ""
        printf "%-#{s + sep.length}s ", e + sep
      end
      puts bar
    end
  end

  def status_bar_for issues
    Issue::STATUS_WIDGET.
      sort_by { |k, v| -Issue::STATUS_SORT_ORDER[k] }.
      map { |k, v| v * issues.count_of { |i| i.status == k } }.
      join
  end

  def todo_list_for issues, opts={}
    return if issues.empty?
    name_len = issues.max_of { |i| i.name.length }
    issues.map do |i|
      s = sprintf "%s %#{name_len}s: %s", i.status_widget, i.name, i.title
      s += " [#{i.release}]" if opts[:show_release] && i.release
      s + "\n"
    end.join
  end

  def print_todo_list_by_release_for project, issues
    by_release = issues.inject({}) do |h, i|
      r = project.release_for(i.release) || :unassigned
      h[r] ||= []
      h[r] << i
      h
    end

    (project.releases + [:unassigned]).each do |r|
      next unless by_release.member? r
      puts r == :unassigned ? "Unassigned:" : "#{r.name} (#{r.status}):"
      print todo_list_for(by_release[r])
      puts
    end
  end

  operation :todo, "Generate todo list", :maybe_release do
    opt :all, "Show all issues, included completed ones", :default => false
  end
  def todo project, config, opts, releases
    actually_do_todo project, config, releases, opts[:all]
  end

  def actually_do_todo project, config, releases, full
    run_pager config
    releases ||= project.unreleased_releases + [:unassigned]
    releases = [*releases]
    releases.each do |r|
      puts r == :unassigned ? "Unassigned:" : "#{r.name} (#{r.status}):"
      issues = project.issues_for_release r
      issues = issues.select { |i| i.open? } unless full
      puts(todo_list_for(issues.sort_by { |i| i.sort_order }) || "No open issues.")
      puts
    end
  end

  operation :show, "Describe a single issue", :issue
  def show project, config, issue
    ScreenView.new(project, config).render_issue issue
  end

  operation :start, "Start work on an issue", :unstarted_issue do
    opt :comment, "Specify a comment", :short => 'm', :type => String
    opt :no_comment, "Skip asking for a comment", :default => false
  end
  def start project, config, opts, issue
    puts "Starting work on issue #{issue.name}: #{issue.title}."
    issue.start_work config.user, get_comment(opts)
    puts "Recorded start of work for #{issue.name}."
  end

  operation :stop, "Stop work on an issue", :started_issue do
    opt :comment, "Specify a comment", :short => 'm', :type => String
    opt :no_comment, "Skip asking for a comment", :default => false
  end
  def stop project, config, opts, issue
    puts "Stopping work on issue #{issue.name}: #{issue.title}."
    issue.stop_work config.user, get_comment(opts)
    puts "Recorded work stop for #{issue.name}."
  end

  operation :close, "Close an issue", :open_issue do
    opt :comment, "Specify a comment", :short => 'm', :type => String
    opt :no_comment, "Skip asking for a comment", :default => false
  end
  def close project, config, opts, issue
    puts "Closing issue #{issue.name}: #{issue.title}."
    disp = ask_for_selection Issue::DISPOSITIONS, "disposition", lambda { |x| Issue::DISPOSITION_STRINGS[x] || x.to_s }
    issue.close disp, config.user, get_comment(opts)
    puts "Closed issue #{issue.name} with disposition #{issue.disposition_string}."
  end

  operation :assign, "Assign an issue to a release", :issue, :maybe_release do
    opt :comment, "Specify a comment", :short => 'm', :type => String
    opt :no_comment, "Skip asking for a comment", :default => false
  end
  def assign project, config, opts, issue, maybe_release
    if maybe_release && maybe_release.name == issue.release
      raise Error, "issue #{issue.name} already assigned to release #{issue.release}"
    end

    puts "Issue #{issue.name} currently " + if issue.release
      "assigned to release #{issue.release}."
    else
      "not assigned to any release."
    end

    release = maybe_release || begin
      releases = project.releases.sort_by { |r| (r.release_time || 0).to_i }
      releases -= [releases.find { |r| r.name == issue.release }] if issue.release
      ask_for_selection(releases, "release") do |r|
        r.name + if r.released?
          " (released #{r.release_time.pretty_date})"
        else
          " (unreleased)"
        end
      end
    end
    issue.assign_to_release release, config.user, get_comment(opts)
    puts "Assigned #{issue.name} to #{release.name}."
  end

  operation :set_component, "Set an issue's component", :issue, :maybe_component do
    opt :comment, "Specify a comment", :short => 'm', :type => String
    opt :no_comment, "Skip asking for a comment", :default => false
  end
  def set_component project, config, opts, issue, maybe_component
    puts "Changing the component of issue #{issue.name}: #{issue.title}."

    if project.components.size == 1
      raise Error, "this project does not use multiple components"
    end

    if maybe_component && maybe_component.name == issue.component
      raise Error, "issue #{issue.name} already assigned to component #{issue.component}"
    end

    component = maybe_component || begin
      components = project.components
      components -= [components.find { |r| r.name == issue.component }] if issue.component
      ask_for_selection(components, "component") { |r| r.name }
    end
    issue.assign_to_component component, config.user, get_comment(opts)
    oldname = issue.name
    project.assign_issue_names!
    puts <<EOS
Issue #{oldname} is now #{issue.name}. Note that the names of other issues may
have changed as well.
EOS
  end

  operation :unassign, "Unassign an issue from any releases", :assigned_issue do
    opt :comment, "Specify a comment", :short => 'm', :type => String
    opt :no_comment, "Skip asking for a comment", :default => false
  end
  def unassign project, config, opts, issue
    puts "Unassigning issue #{issue.name}: #{issue.title}."
    issue.unassign config.user, get_comment(opts)
    puts "Unassigned #{issue.name}."
  end

  operation :comment, "Comment on an issue", :issue do
    opt :comment, "Specify a comment", :short => 'm', :type => String
    opt :no_comment, "Skip asking for a comment", :default => false
  end
  def comment project, config, opts, issue
    puts "Commenting on issue #{issue.name}: #{issue.title}."
    comment = get_comment opts
    if comment.blank?
      puts "Empty comment, aborted."
    else
      issue.log "commented", config.user, comment
      puts "Comments recorded for #{issue.name}."
    end
  end

  operation :releases, "Show releases"
  def releases project, config
    run_pager config
    a, b = project.releases.partition { |r| r.released? }
    (b + a.sort_by { |r| r.release_time }).each do |r|
      status = r.released? ? "released #{r.release_time.pretty_date}" : r.status
      puts "#{r.name} (#{status})"
    end
  end

  operation :release, "Release a release", :unreleased_release do
    opt :comment, "Specify a comment", :short => 'm', :type => String
    opt :no_comment, "Skip asking for a comment", :default => false
  end
  def release project, config, opts, release
    release.release! project, config.user, get_comment(opts)
    puts "Release #{release.name} released!"
  end

  operation :changelog, "Generate a changelog for a release", :release
  def changelog project, config, r
    run_pager config
    puts "== #{r.name} / #{r.released? ? r.release_time.pretty_date : 'unreleased'}"
    project.group_issues(project.issues_for_release(r)).each do |type, issues|
      issues.select { |i| i.closed? }.each do |i|
        if type == :bugfix
          puts "* #{type}: #{i.title}"
        else
          puts "* #{i.title}"
        end
      end
    end
  end

  operation :html, "Generate html status pages", :maybe_dir
  def html project, config, dir
    dir ||= "html"
    HtmlView.new(project, config, dir).render_all
  end

  operation :rdf, "Generate baetle file", :maybe_dir
  def rdf project, config, dir
    dir ||= "baetle"
    BaetleView.new(project, config, dir).render_all
  end

  COL_ID = "ID"
  COL_NAME = "NAME"
  COL_RELEASE = "RELEASE"
  operation :list, "Show all issues"
  def list project, config
    issues = project.issues
    return if issues.empty?

    run_pager config
    name_len = issues.max_of { |i| i.name.length }
    name_len = COL_NAME.length if name_len < COL_NAME.length
    release_len = project.releases.max_of { |i| i.name.length }
    release_len = COL_RELEASE.length if !release_len || release_len < COL_RELEASE.length
    s = "  #{COL_ID.ljust(40)} #{COL_NAME.ljust(name_len)} #{COL_RELEASE.ljust(release_len)} TITLE\n"
    issues.map do |i|
      s += sprintf "%s %s %-#{name_len}s %-#{release_len}s %s\n", i.status_widget, i.id, i.name, i.release, i.title
    end.join
    puts s
  end

  operation :validate, "Validate project status"
  def validate project, config
    ## a no-op
  end

  operation :grep, "Show issues matching a string or regular expression", :string do
    opt :ignore_case, "Ignore case distinctions in both the expression and in the issue data", :default => false
  end

  def grep project, config, opts, match
    run_pager config
    re = Regexp.new match, opts[:ignore_case]
    issues = project.issues.select do |i|
      i.title =~ re || i.desc =~ re ||
        i.log_events.map { |time, who, what, comments| comments }.join(" ") =~ re
    end
    puts(todo_list_for(issues) || "No matching issues.")
  end

  operation :log, "Show recent activity"
  def log project, config
    run_pager config
    project.issues.map { |i| i.log_events.map { |e| [e, i] } }.
      flatten_one_level.sort_by { |e| e.first.first }.reverse.
      each do |(date, author, what, comment), i|
      puts <<EOS
date  : #{date.localtime} (#{date.ago} ago)
author: #{author}
    id: #{i.id}
 issue: [#{i.name}] #{i.title}

  #{what}
#{comment.gsub(/^/, "  > ") unless comment =~ /^\A\s*\z/}
EOS
    puts unless comment.blank?
    end
  end

  operation :shortlog, "Show recent activity (short form)"
  def shortlog project, config
    run_pager config
    project.issues.map { |i| i.log_events.map { |e| [e, i] } }.
      flatten_one_level.sort_by { |e| e.first.first }.reverse.
      each do |(date, author, what, comment), i|
        shortauthor = if author =~ /<(.*?)@/
          $1
        else
          author
        end[0..15]
        printf "%13s|%13s|%13s|%s\n", date.ago, i.name, shortauthor,
          what
      end
  end

  operation :archive, "Archive a release", :release, :maybe_dir do
    opt :dir, "Specify the archive directory", :short => 'd', :type => String
  end
  def archive project, config, opts, release
    dir = opts[:dir] || "./ditz-archive-#{release.name}"
    FileUtils.mkdir dir
    FileUtils.cp project.pathname, dir
    project.issues_for_release(release).each do |i|
      FileUtils.cp i.pathname, dir
      project.drop_issue i
    end
    project.drop_release release
    puts "Archived to #{dir}. Note that issue names may have changed."
  end

  operation :edit, "Edit an issue", :issue do
    opt :comment, "Specify a comment", :short => 'm', :type => String
    opt :no_comment, "Skip asking for a comment", :default => false
    opt :silent, "Don't add a log message detailing the change", :default => false
  end
  def edit project, config, opts, issue
    data = { :title => issue.title, :description => issue.desc,
             :reporter => issue.reporter }

    fn = run_editor { |f| f.puts data.to_yaml }

    unless fn
      puts "Aborted."
      return
    end

    begin
      edits = YAML.load_file fn
      comment = opts[:silent] ? nil : get_comment(opts)
      if issue.change edits, config.user, comment, opts[:silent]
        puts "Change recorded."
      else
        puts "No changes."
      end
    end
  end
end

end
