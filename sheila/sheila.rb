require 'rubygems'
require 'ditz'
require 'socket'
require 'trollop'
require 'fastthread'

## require ditz's camping
# $:.push File.expand_path(File.join(File.dirname(__FILE__), "../camping/lib"))
require 'camping'
require 'camping/server'

Camping.goes :Sheila

class String
  def obfu; gsub(/( <.+?)@.+>$/, '\1@...>') end
  def prefix; self[0,8] end
end

class Ditz::Release
  def fancy_name
    if released?
      "#{name} (#{release_time.ago} ago)"
    else
      name
    end
  end
end

hostname = begin
  Socket.gethostbyname(Socket.gethostname).first
rescue SocketError
  Socket.gethostname
end

## tweak these if you want!
GIT_AUTHOR_NAME = "Sheila"
GIT_AUTHOR_EMAIL = "sheila@#{hostname}"
CONFIG_FN = ".ditz-config"
PLUGIN_FN = ".ditz-plugins"

class Hash
  ## allow "a[b]" lookups for two-level nested hashes. returns empty strings
  ## instead of nil.
  def resolve s
    raise ArgumentError, "not in expected format" unless s =~ /(\S+?)\[(\S+?)\]$/
    a, b = $1, $2
    (self[a] && self[a][b]) || ""
  end
end

## config holders
class << Sheila
  attr_reader :project, :config, :storage
  def create
    ## load plugins
    plugin_fn = File.join Ditz::find_dir_containing(PLUGIN_FN) || ".", PLUGIN_FN
    Ditz::load_plugins(plugin_fn) if File.exist?(plugin_fn)

    ## load config
    config_fn = File.join Ditz::find_dir_containing(CONFIG_FN) || ".", CONFIG_FN
    Ditz::debug "loading config from #{config_fn}"
    @config = Ditz::Config.from config_fn
    @config.name = GIT_AUTHOR_NAME # just overwrite these two fields
    @config.email = GIT_AUTHOR_EMAIL

    ## load project
    @storage = Ditz::FileStorage.new File.join(File.dirname(config_fn), @config.issue_dir)
    @project = @storage.load

    @mutex = Mutex.new
  end

  def add_issue! issue
    @mutex.synchronize do
      @project.add_issue issue
      save! "added issue #{issue.id.prefix}"
    end
  end

  def add_comment! issue, author, comment
    @mutex.synchronize do
      issue.log "commented", author, comment
      save! "comment on #{issue.id.prefix}"
    end
  end

private

  def save! message
    message = message.gsub(/'/, "")
    @storage.save @project
    ENV["GIT_AUTHOR_NAME"] = GIT_AUTHOR_NAME
    ENV["GIT_AUTHOR_EMAIL"] = GIT_AUTHOR_EMAIL
    system "git add #{File.dirname @project.pathname}/*.yaml"
    system "git commit -m 'issue update via Sheila: #{message}'"
  end
end

module Sheila::Controllers
  class Index
    def get 
      ## process filter parameters
      type, type_check = case(t = @input["type"])
        when "open"; ["open", lambda { |i| i.open? }]
        when "closed"; ["closed", lambda { |i| i.closed? }]
        when "in_progress"; ["in progress", lambda { |i| i.in_progress? }]
        end

      release, release_check = case(r = @input["release"])
        when "unassigned"; [:unassigned, lambda { |i| i.release.nil? }]
        when String
          release = Sheila.project.release_for r
          [release, release && lambda { |i| i.release == release.name }]
        end

      component, component_check = case(c = @input["component"])
        when String
          component = Sheila.project.component_for c
          [component, component && lambda { |i| i.component == component.name }]
        end

      query, query_check = case(q = @input["query"])
        when /\S/
          re = Regexp.new q, true
          [q, lambda { |i| i.title =~ re || i.desc =~ re || i.log_events.map { |time, who, what, comments| comments }.join(" ") =~ re }]
        end

      ## build issue list
      @issues = Sheila.project.issues.select do |i|
        (type_check.nil? || type_check[i]) &&
          (release_check.nil? || release_check[i]) &&
          (component_check.nil? || component_check[i]) &&
          (query_check.nil? || query_check[i])
      end.sort_by { |i| i.last_event_time || i.creation_time }.reverse

      ## build title
      @title = [
        @issues.size,
        type,
        (release == :unassigned ? "unassigned" : nil),
        (component ? component.name : nil),
        (@issues.size == 1 ? "issue" : "issues"),
        (Ditz::Release === release ? "in #{release.name}" : nil),
        (query ? "matching #{query.inspect}" : nil),
      ].compact.join(" ")

      ## decide whether to show the "add new issue" link
      @show_add_link = true

      ## go!
      render :index
    end
  end
  class TicketX
    def initialize(*a)
      super(*a)
      @errors = []
    end
    def get sha
      len = sha.length
      @issue = Sheila.project.issues.find { |i| i.id[0 ... len] == sha }
      render :ticket
    end
    def post sha
      len = sha.length
      @issue = Sheila.project.issues.find { |i| i.id[0 ... len] == sha }

      # extra validation. probably not great that it's here.
      @errors << "email address is invalid" unless @input.resolve("comment[author]") =~ /@/
      @errors << "comment text is empty" unless @input.resolve("comment[text]") =~ /\S/

      if @errors.empty?
        comment = @input.resolve "comment[text]"
        comment += "\n\n(submitted via Sheila by #{@env['REMOTE_ADDR']} (#{@env['REMOTE_HOST']}))"

        Sheila.add_comment! @issue, @input.resolve("comment[author]"), comment
        @input["comment"] = {} # clear fields
      end

      render :ticket
    end
  end
  class New
    def initialize *a
      super(*a)
      @errors = []
    end

    def get
      render :editor
    end
    def post
      @input['ticket']['release'] = nil if @input['ticket']['release'] == ""
      @input['ticket']['type'] = @input.resolve("ticket[type]").intern unless @input.resolve("ticket[type]") == ""
      @input['ticket']['component'] ||= Sheila.project.components.first.name

      # extra validation. probably not great that it's here.
      @errors << "the email address was invalid" unless @input["ticket"]["reporter"] =~ /@/

      if @errors.empty?
        begin 
          @issue = Ditz::Issue.create @input['ticket'], [Sheila.config, Sheila.project]
          @issue.log "created", @input.resolve("ticket[reporter]"), "Created via Sheila by #{@env['REMOTE_HOST']} (#{@env['REMOTE_ADDR']})"
          Sheila.add_issue! @issue
        rescue Ditz::ModelError => e
          @errors << e.message
        end
      end

      if @errors.empty?
        redirect TicketX, @issue.id
      else
        render :editor
      end
    end
  end
  class Signup
    def get
      @me = User.new
      render :profile
    end
  end
  class ReleaseX
    def get num
      @release = Sheila.project.releases[num.to_i] # see docs for Views#ticket
      @created, @desc = @release.log_events[0].first, @release.log_events[0].last
      @issues = Sheila.project.issues_for_release @release
      render :release
    end
  end
  class Unassigned
    def get
      @release = nil
      @issues = Sheila.project.unassigned_issues
      render :release
    end
  end
  class Style < R '/styles.css'
    def get
      @headers["Content-Type"] = "text/css; charset=utf-8"
      @body = Sheila::CSS
    end
  end
end

module Sheila::Views
  def layout
    html do
      head do
        title "Sheila: #{Sheila.project.name}"
        link :rel => 'stylesheet', :type => 'text/css', 
             :href => '/styles.css', :media => 'screen'
      end
      body do
        h1.header { a Sheila.project.name, :href => R(Index) }
        div.content do
          self << yield
        end
      end
    end
  end

  def filter_list
    form.filters :action => R(Index) do
      fieldset.filters do
        span "Status: "
        select.filter :name => "type" do
          option "all", prune_opts(:selected => ["all", "", nil].member?(@input["type"]), :value => "")
          option "open", prune_opts(:selected => @input["type"] == "open", :value => "open")
          option "closed", prune_opts(:selected => @input["type"] == "closed", :value => "closed")
          option "in progress", prune_opts(:selected => @input["type"] == "in_progress", :value => "in_progress")
        end
        span " Release: "
        select.filter :name => "release" do
          option "all", prune_opts(:selected => ["all", "", nil].member?(@input["release"]), :value => "")
          Sheila.project.releases.sort_by { |r| r.release_time || Time.now }.reverse.each do |r|
            option r.fancy_name, prune_opts(:value => r.name, :selected => @input["release"] == r.name)
          end
          option "Unassigned", prune_opts(:selected => @input["release"] == "unassigned", :value => "")
        end
        if Sheila.project.components.size > 1
          span " Component: "
          select.filter :name => "component" do
            option "all", prune_opts(:selected => ["all", "", nil].member?(@input["component"]), :value => "")
            Sheila.project.components.each do |c|
              option c.name, prune_opts(:value => c.name, :selected => @input["component"] == c.name)
            end
          end
        end
        span " Search: "
        input :value => @input["query"], :name => "query", :size => 10
        text " "
        input :value => ">", :type => "submit"
      end
    end
  end

  def search_results
    filter_list
    h2 "#{'result'.pluralize @issues.size} for #{@query.inspect}"

    unless @issues.empty?
      ticket_table @issues, :show_add_link => false
    end
  end

  def index
    filter_list
    h2 @title
    ticket_table @issues, :show_add_link => @show_add_link, :add_link_params => @add_link_params
  end

  def ticket_table issues, opts={}
    show_add_link = opts[:show_add_link]
    add_link_params = opts[:add_link_params]

    h4 "Issues"
    table.tickets! do
      tr do
        th "ID"
        th "Title"
        th "State"
      end
      tr do
        td.unique ""
        add_link_extra = add_link_params ? "?" + add_link_params.map { |k, v| "#{k}=#{v}" }.join("&") : ""
        td.title { a "Add a new issue", :href => R(New) + add_link_extra }
        td.status ""
      end if show_add_link
      issues.each do |issue|
        tr do
          td.unique issue.id.prefix
          td.title do
            h3 { a issue.title, :href => R(TicketX, issue.id) }
            p.about do
              strong("#{(issue.last_event_time || issue.creation_time).ago} ago")
              span(" by #{issue.reporter.obfu}")
              comments = issue.log_events.select { |e| e[2] == "commented" } # :(
              unless comments.empty?
                name = case comments.size
                when 1; "1 comment"
                else "#{comments.size} comments"
                end
                span { a " (#{name})", :href => R(TicketX, issue.id) + "#log" }
              end
            end
          end
          td.status { issue.status.to_s.gsub(/_/, "&nbsp;") }
        end
      end
    end
  end

  def release
    filter_list
    h2(@release ? @release.name : "Unassigned issues")

    if @release.release_time
      h3 "Released #{@release.release_time.ago} ago"
    else
      h3 "Started #{@created.ago} ago"
    end if @release

    div.description do
      text link_issue_names(@desc) if @desc
    end

    ticket_table @issues, :show_add_link => (@release.nil? || @release.unreleased?), :add_link_params => { "release" => (@release.nil? ? "unassigned" : @release.name) }
  end

  def ticket
    h2 @issue.title
    h3 { span.unique.right @issue.id.prefix; span "created #{@issue.creation_time.ago} ago by #{@issue.reporter.obfu}" }
    div.description do
      text link_issue_names(@issue.desc)
    end unless @issue.desc.blank?
    div.details do
      p { strong "Type: "; span @issue.type.to_s }
      ## unfortunately this next thing always raises a "bad route" if the
      ## release name has any dots or dashes in it
      #p { strong "Release: "; a @issue.release, :href => R(ReleaseX, @issue.release) }
      ## instead, we do this foul thing:
      foul = Sheila.project.releases.map { |r| r.name }.index @issue.release
      p do
        strong "Release: "
        if @issue.release
          a @issue.release, :href => R(ReleaseX, foul)
        else
          a "unassigned", :href => R(Unassigned)
        end
      end
      p { strong "Status: "; span @issue.status.to_s }
    end
    h4 "Log"
    a :name => "log"
    issue_log @issue.log_events, @errors
  end

  def link_issue_names s
    Sheila.project.issues.inject(s) do |s, i|
      s.gsub(/\b#{i.name}\b/, a("[#{i.id.prefix}]", :href => R(TicketX, i.id), :title => i.title, :name => i.title))
    end
  end

  def issue_log log, form_errors
    ul.events do
      log.each do |at, name, action, comment|
        li do
          div.ago "#{at.ago} ago"
          div.who name.obfu
          div.action action
          div.comment do
            text link_issue_names(comment)
          end unless comment.blank?
        end
      end

      # new comment form
      a :name => "new-comment"
      li do
        form :method => 'POST', :action => R(TicketX, issue.id) + "#new-comment" do
          fieldset do
            div.required do
              p.error "Sorry, I couldn't add that comment: #{@errors.first}" unless @errors.empty?
              label.fieldname 'Comment', :for => 'comment'
              textarea.standard @input.resolve("comment[text]"), :name => 'comment[text]'
            end
            div.required do
              label.fieldname 'Your name & email', :for => 'ticket[reporter]'
              div.fielddesc { "In standard email format, e.g. \"Bob Bobson &lt;bob@bobson.com&gt;\"" }
              input.standard :name => 'comment[author]', :type => 'text', :value => @input.resolve("comment[author]")
            end
            div.buttons do
              input :name => 'submit', :value => 'Submit comment', :type => 'submit'
            end
          end
        end
      end
    end
  end

  ## removes any instances of the tags in +remove+ that have values of
  ## false or nil. this is because they can't appear in the HTML, even
  ## if they're empty.
  def prune_opts opts, remove=[:selected, :checked]
    remove.each { |k| opts.delete(k) unless opts[k] }
    opts
  end

  def editor
    h2 "Submit a new #{Sheila.project.name} issue"

    p.error "Sorry, I couldn't create that issue: #{@errors.first}" unless @errors.empty?

    form :method => 'POST', :action => R(New) do
      fieldset do
        div.required do
          label.fieldname 'Summary', :for => 'ticket[title]'
          div.fielddesc { "A brief summary of the issue" }
          input.standard :name => 'ticket[title]', :type => 'text', :value => @input.resolve("ticket[title]")
        end
        div.required do
          label.fieldname 'Details', :for => 'ticket[desc]'
          div.fielddesc { "All relevant details. For bug reports, be sure to include the version of #{Sheila.project.name}, and all information necessary to reproduce the bug." }
          textarea.standard @input.resolve("ticket[desc]"), :name => 'ticket[desc]'
        end
        div.required do
          label.fieldname 'Your name & email', :for => 'ticket[reporter]'
          div.fielddesc { "In standard email format, e.g. \"Bob Bobson &lt;bob@bobson.com&gt;\"" }
          input.standard :name => 'ticket[reporter]', :type => 'text', :value => @input.resolve("ticket[reporter]")
        end
        div.required do
          label.fieldname 'Issue type'
          div do

            current_type = case(x = @input.resolve("ticket[type]"))
              when ""; :bugfix
              when String; x.intern
            end

            Ditz::Issue::TYPES.each do |t|
              input prune_opts(:type => 'radio', :name => 'ticket[type]', :value => t.to_s, :id => "ticket[type]-#{t}", :checked => (current_type == t))
              label " #{t} ", :for => "ticket[type]-#{t}"
            end
          end
        end
        div.required do
          label.fieldname 'Release, if any', :for => 'ticket[release]'
          current_r = @input.resolve "ticket[release]"
          current_r = @input["release"] if current_r.blank?
          select.standard :name => 'ticket[release]' do
            option "No release", prune_opts(:selected => current_r.blank? || current_r == "unassigned", :value => "")
            Sheila.project.releases.select { |r| r.unreleased? }.each do |r|
              option r.fancy_name, prune_opts(:value => r.name, :selected => current_r == r.name)
            end
          end
        end
        if Sheila.project.components.size > 1
          label.fieldname "Component", :for => 'ticket[component]'
          select.standard :name => 'ticket[component]' do
            Sheila.project.components.each { |c| option c.name, prune_opts(:selected => @input.resolve("ticket[component]") == c.name) }
          end
        end
        div.buttons do
          input :name => 'submit', :value => 'Submit issue', :type => 'submit'
        end
      end
    end
  end

  def dewikify(str)
    str.split(/\s*?(\{{3}(?:.+?)\}{3})|\n\n/m).map do |para|
      next if para.empty?
      if para =~ /\{{3}(?:\s*\#![^\n]+)?(.+?)\}{3}/m
        self << 
          pre($1).to_s.gsub(/ +#=\&gt;.+$/, '<span class="outputs">\0</span>').
            gsub(/ +# .+$/, '<span class="comment">\0</span>')
      else
        case para
        when /\A\* (.+)/m
          ul { $1.split(/^\* /).map { |x| li x } }
        when /\A==== (.+) ====/
          h4($1)
        when /\A=== (.+) ===/
          h3($1)
        when /\A== (.+) ==/
          h2($1)
        when /\A= (.+) =/
          h1($1)
        else
          p(para)
        end
        # txt.gsub(/`(.+?)`/m, '<code>\1</code>').gsub(/\[\[BR\]\]/i, '<br />').
        #   gsub(/'''(.+?)'''/m, '<strong>\1</strong>').gsub(/''(.+?)''/m, '<em>\1</em>').   
        #   gsub(/\[\[(\S+?) (.+?)\]\]/m, '<a href="\1">\2</a>').
        #   gsub(/\(\!\)/m, '<img src="/static/exclamation.png" />').
        #   gsub(/\!\\(\S+\.png)\!/, '<img class="inline" src="/static/\1" />').
        #   gsub(/\!(\S+\.png)\!/, '<img src="/static/\1" />')
      end
    end
  end
end

Sheila::CSS = <<END
body { font: 0.75em/1.5 'Lucida Grande', sans-serif; color: #333; }
* { margin: 0; padding: 0; }
a { text-decoration: none; color: blue; }
a:hover { text-decoration: underline; }
h2 { font-size: 36px; font-weight: normal; line-height: 120%; padding-bottom: 0.5em; padding-top: 0.5em; }

label.fieldname {
  font-size: large;
  display: block;
}
div.fielddesc {
  font-size: x-small;
}
h1.header {
  background-color: #660;
  margin: 0; padding: 4px 16px;
  width: 740px;
  margin: 0 auto;
}
h1.header a {
  color: #fef;
}
fieldset {
  border: none;
}
h3.field {
  display: inline;
  background-color: #eee;
  padding: 4px;
}
div.required {
  margin: 6px 0;
}
div.buttons {
  border-top: solid 1px #eee;
  padding: 6px 0;
}
input {
  padding: 4px;
}
input.standard {
  width: 100%;
}
select.standard {
  width: 100%;
}
textarea.standard {
  width: 100%;
  height: 10em;
}
.right {
  float: right;
  width: 200px;
}
.full {
  width: 500px;
}
div.right {
  margin-right: 120px;
}

#tickets {
  margin: 20px 0;
}
#tickets td {
  font-size: 14px;
  padding: 5px;
  border-bottom: solid 1px #eee;
}
#tickets th {
  font-size: 14px;
  padding: 5px;
  border-bottom: solid 3px #ccc;
}
#tickets td .about {
  font-size: 11px;
}
div.content {
  padding: 10px;
  width: 740px;
  margin: 0 auto;
}
p.error {
  color: red;
}
div.details {
  border-top: solid 1px #eee;
  margin: 10px 0;
  padding: 16px 0;
}
h4 {
  color: white;
  background-color: #ccc;
  padding: 2px 6px;
}
ul.events li {
  border-bottom: solid 1px #eee;
  list-style: none;
  padding: 10px 0;
}
div.description {
  padding: 10px;
  white-space: pre;
  font-size: large;
}
div.ago {
  font-weight: bold;
}
div.action {
  color: #a09;
}
ul.events div.ago,
ul.events div.who {
  display: block;
  padding-right: 20px;
  float: left;
}
ul.events div.comment {
  background-color: #ffc;
  padding: 3px;
  color: #777;
  white-space: pre;
}
.unique {
  color: #999;
}
fieldset.filters input {
  font-size: x-small;
  padding: 1px;
}
form.filters {
  text-align: right;
}
END

##### EXECUTION STARTS HERE #####
if __FILE__ == $0

opts = Trollop::options do
  version "sheila (ditz version #{Ditz::VERSION})"

  opt :verbose, "Verbose output", :default => false
  opt :host, "Host on which to run", :default => "0.0.0.0"
  opt :port, "Port on which to run", :default => 1234
  opt :server, "Camping server type to use (mongrel, webrick, console, any)", :default => "any"
end

Ditz::verbose = opts[:verbose]

if opts[:server] == "any"
  begin
    require 'mongrel'
    opts[:server] = "mongrel"
  rescue LoadError
    $stderr.puts "!! Could not load mongrel. Falling back to webrick."
    opts[:server] = "webrick"
  end
end

## next part stolen from camping/server.rb.
handler, conf = case opts[:server]
when "console"
  ARGV.clear
  IRB.start
  exit
when "mongrel"
  puts "** Starting Mongrel on #{opts[:host]}:#{opts[:port]}"
  [Rack::Handler::Mongrel, {:Port => opts[:port], :Host => opts[:host]}]
when "webrick"
  [Rack::Handler::WEBrick, {:Port => opts[:port], :BindAddress => opts[:host]}]
end

Sheila.create
rapp = Sheila
rapp = Rack::Lint.new rapp
rapp = Camping::Server::XSendfile.new rapp
rapp = Rack::ShowExceptions.new rapp
handler.run rapp, conf

end
