require 'model'

module Ditz

class Component < ModelObject
  field :name
  def name_prefix; name.gsub(/\s+/, "-").downcase end
end

class Release < ModelObject
  class Error < StandardError; end

  field :name
  field :status, :default => :unreleased, :ask => false
  field :release_time, :ask => false
  changes_are_logged

  def released?; self.status == :released end
  def unreleased?; !released? end

  def issues_from project; project.issues.select { |i| i.release == name } end

  def release! project, who, comment
    raise Error, "already released" if released?

    issues = issues_from project
    bad = issues.find { |i| i.open? }
    raise Error, "open issue #{bad.name} must be reassigned" if bad

    self.release_time = Time.now
    self.status = :released
    log "released", who, comment
  end
end

class Project < ModelObject
  class Error < StandardError; end

  field :name, :default_generator => lambda { File.basename(Dir.pwd) }
  field :version, :default => Ditz::VERSION, :ask => false
  field :components, :multi => true, :generator => :get_components
  field :releases, :multi => true, :ask => false

  ## issues are not model fields proper, so we build up their interface here.
  attr_reader :issues
  def issues= issues
    @issues = issues
    @issues.each { |i| i.project = self }
    assign_issue_names!
    issues
  end

  def add_issue issue
    added_issues << issue
    issues << issue
    issue.project = self
    assign_issue_names!
    issue
  end

  def drop_issue issue
    if issues.delete issue
      deleted_issues << issue
      assign_issue_names!
    end
  end

  def added_issues; @added_issues ||= [] end
  def deleted_issues; @deleted_issues ||= [] end

  def get_components
    puts <<EOS
Issues can be tracked across the project as a whole, or the project can be
split into components, and issues tracked separately for each component.
EOS
    use_components = ask_yon "Track issues separately for different components?"
    comp_names = use_components ? ask_for_many("components") : []

    ([name] + comp_names).uniq.map { |n| Component.create_interactively :with => { :name => n } }
  end

  def issues_for ident
    by_name = issues.find { |i| i.name == ident }
    by_name ? [by_name] : issues.select { |i| i.id =~ /^#{ident}/ }
  end

  def component_for component_name
    components.find { |i| i.name == component_name }
  end

  def release_for release_name
    releases.find { |i| i.name == release_name }
  end

  def unreleased_releases; releases.select { |r| r.unreleased? } end

  def issues_for_release release
    release == :unassigned ? unassigned_issues : issues.select { |i| i.release == release.name }
  end

  def issues_for_component component
    issues.select { |i| i.component == component.name }
  end

  def unassigned_issues
    issues.select { |i| i.release.nil? }
  end

  def group_issues these_issues=issues
    these_issues.group_by { |i| i.type }.sort_by { |(t,g)| Issue::TYPE_ORDER[t] }
  end

  def assign_issue_names!
    prefixes = components.map { |c| [c.name, c.name.gsub(/^\s+/, "-").downcase] }.to_h
    ids = components.map { |c| [c.name, 0] }.to_h
    issues.sort_by { |i| i.creation_time }.each do |i|
      i.name = "#{prefixes[i.component]}-#{ids[i.component] += 1}"
    end
  end

  def validate!
    if(dup = components.map { |c| c.name }.first_duplicate)
      raise Error, "more than one component named #{dup.inspect}: #{components.inspect}"
    elsif(dup = releases.map { |r| r.name }.first_duplicate)
      raise Error, "more than one release named #{dup.inspect}"
    end
  end

  def self.from *a
    p = super(*a)
    p.validate!
    p
  end
end

class Issue < ModelObject
  class Error < StandardError; end

  field :title
  field :desc, :prompt => "Description", :multiline => true
  field :type, :generator => :get_type
  field :component, :generator => :get_component
  field :release, :generator => :get_release
  field :reporter, :prompt => "Issue creator", :default_generator => lambda { |config, proj| config.user }
  field :status, :ask => false, :default => :unstarted
  field :disposition, :ask => false
  field :creation_time, :ask => false, :generator => lambda { Time.now }
  field :references, :ask => false, :multi => true
  field :id, :ask => false, :generator => :make_id
  changes_are_logged

  attr_accessor :name, :pathname, :project

  ## these are the fields we interpolate issue names on
  INTERPOLATED_FIELDS = [:title, :desc, :log_events]

  STATUS_SORT_ORDER = { :unstarted => 2, :paused => 1, :in_progress => 0, :closed => 3 }
  STATUS_WIDGET = { :unstarted => "_", :in_progress => ">", :paused => "=", :closed => "x" }
  DISPOSITIONS = [ :fixed, :wontfix, :reorg ]
  TYPES = [ :bugfix, :feature, :task ]
  TYPE_ORDER = { :bugfix => 0, :feature => 1, :task => 2 }
  TYPE_LETTER = { 'b' => :bugfix, 'f' => :feature, 't' => :task }
  STATUSES = STATUS_WIDGET.keys

  STATUS_STRINGS = { :in_progress => "in progress", :wontfix => "won't fix" }
  DISPOSITION_STRINGS = { :wontfix => "won't fix", :reorg => "reorganized" }

  def serialized_form_of field, value
    return super unless INTERPOLATED_FIELDS.member? field

    if field == :log_events
      value.map do |time, who, what, comment|
        comment = @project.issues.inject(comment) do |s, i|
          s.gsub(/\b#{i.name}\b/, "{issue #{i.id}}")
        end
        [time, who, what, comment]
      end
    else
      @project.issues.inject(value) do |s, i|
        s.gsub(/\b#{i.name}\b/, "{issue #{i.id}}")
      end
    end
  end

  def deserialized_form_of field, value
    return super unless INTERPOLATED_FIELDS.member? field

    if field == :log_events
      value.map do |time, who, what, comment|
        comment = @project.issues.inject(comment) do |s, i|
          s.gsub(/\{issue #{i.id}\}/, i.name)
        end.gsub(/\{issue \w+\}/, "[unknown issue]")
        [time, who, what, comment]
      end
    else
      @project.issues.inject(value) do |s, i|
        s.gsub(/\{issue #{i.id}\}/, i.name)
      end.gsub(/\{issue \w+\}/, "[unknown issue]")
    end
  end

  ## make a unique id
  def make_id config, project
    SHA1.hexdigest [Time.now, rand, creation_time, reporter, title, desc].join("\n")
  end

  def sort_order; [STATUS_SORT_ORDER[status], creation_time] end
  def status_widget; STATUS_WIDGET[status] end

  def status_string; STATUS_STRINGS[status] || status.to_s end
  def disposition_string; DISPOSITION_STRINGS[disposition] || disposition.to_s end

  def closed?; status == :closed end
  def open?; !closed? end
  def in_progress?; status == :in_progress end
  def unstarted?; !in_progress? end
  def bug?; type == :bugfix end
  def feature?; type == :feature end
  def unassigned?; release.nil? end
  def assigned?; !unassigned? end

  def start_work who, comment; change_status :in_progress, who, comment end
  def stop_work who, comment
    raise Error, "unstarted" unless self.status == :in_progress
    change_status :paused, who, comment
  end

  def close disp, who, comment
    raise Error, "unknown disposition #{disp}" unless DISPOSITIONS.member? disp
    log "closed with disposition #{disp}", who, comment
    self.status = :closed
    self.disposition = disp
  end

  def change_status to, who, comment
    raise Error, "unknown status #{to}" unless STATUSES.member? to
    raise Error, "already marked as #{to}" if status == to
    log "changed status from #{status} to #{to}", who, comment
    self.status = to
  end
  private :change_status

  def change hash, who, comment
    what = []
    if title != hash[:title]
      what << "changed title"
      self.title = hash[:title]
    end

    if desc != hash[:description]
      what << "changed description"
      self.desc = hash[:description]
    end

    if reporter != hash[:reporter]
      what << "changed reporter"
      self.reporter = hash[:reporter]
    end

    unless what.empty?
      log what.join(", "), who, comment
      true
    end
  end

  def assign_to_release release, who, comment
    log "assigned to release #{release.name} from #{self.release || 'unassigned'}", who, comment
    self.release = release.name
  end

  def assign_to_component component, who, comment
    log "assigned to component #{component.name} from #{self.component}", who, comment
    self.component = component.name
  end

  def unassign who, comment
    raise Error, "not assigned to a release" unless release
    log "unassigned from release #{release}", who, comment
    self.release = nil
  end

  def get_type config, project
    type = ask "Is this a (b)ugfix, a (f)eature, or a (t)ask?", :restrict => /^[bft]$/
    TYPE_LETTER[type]
  end

  def get_component config, project
    if project.components.size == 1
      project.components.first
    else
      ask_for_selection project.components, "component", :name
    end.name
  end

  def get_release config, project
    releases = project.releases.select { |r| r.unreleased? }
    if !releases.empty? && ask_yon("Assign to a release now?")
      if releases.size == 1
        r = releases.first
        puts "Assigning to release #{r.name}."
        r
      else
        ask_for_selection releases, "release", :name
      end.name
    end
  end

  def get_reporter config, project
    reporter = ask "Creator", :default => config.user
  end
end

class Config < ModelObject
  field :name, :prompt => "Your name", :default_generator => :get_default_name
  field :email, :prompt => "Your email address", :default_generator => :get_default_email
  field :issue_dir, :ask => false, :default => "bugs"

  def user; "#{name} <#{email}>" end

  def get_default_name
    require 'etc'

    name = Etc.getpwnam(ENV["USER"])
    name = name ? name.gecos.split(/,/).first : ""
  end

  def get_default_email
    require 'socket'
    email = (ENV["USER"] || "") + "@" +
      begin
        Socket.gethostbyname(Socket.gethostname).first
      rescue SocketError
        Socket.gethostname
      end
  end
end

end
