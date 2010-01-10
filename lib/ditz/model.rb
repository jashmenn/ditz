require 'yaml'
require "yaml_waml"
if RUBY_VERSION >= '1.9.0'
require 'digest/sha1'
else
require 'sha1'
end
require "ditz/lowline"; include Lowline
require "ditz/util"

class Time
  alias :old_to_yaml :to_yaml
  def to_yaml(opts = {})
    self.utc.old_to_yaml(opts)
  end
end

module Ditz

class ModelError < StandardError; end

class ModelObject
  def initialize
    @values = {}
    @serialized_values = {}
    self.class.fields.map { |f, opts| @values[f] = [] if opts[:multi] }
  end

  ## override me and throw ModelErrors if necessary
  def validate! whence, context
  end

  ## yamlability
  def self.yaml_domain; "ditz.rubyforge.org,2008-03-06" end
  def self.yaml_other_thing; name.split('::').last.dcfirst end
  def to_yaml_type; "!#{self.class.yaml_domain}/#{self.class.yaml_other_thing}" end
  def self.inherited subclass
    YAML.add_domain_type(yaml_domain, subclass.yaml_other_thing) do |type, val|
      o = subclass.new
      val.each do |k, v|
        m = "__serialized_#{k}="
        if o.respond_to? m
          o.send m, v
        else
          $stderr.puts "warning: unknown field #{k.inspect} in YAML for #{type}; ignoring"
        end
      end
      o.class.fields.each do |f, opts|
        m = "__serialized_#{f}"
        if opts[:multi] && o.send(m).nil?
          o.send(m + '=', [])
        end
      end
      o.unchanged!
      o
    end
  end

  ## override these two to model per-field transformations between disk and
  ## memory.
  ##
  ## convert disk form => memory form
  def deserialized_form_of field, value
    value
  end

  ## convert memory form => disk form
  def serialized_form_of field, value
    value
  end

  ## Add a field to a model object
  ##
  ## The options you specify here determine how the field is populated when an
  ## instance of this object is created. Objects can be created interactively,
  ## with #create_interactively, or non-interactively, with #create, and the
  ## creation mode, combined with these options, determine how the field is
  ## populated on a new model object.
  ##
  ## The default behavior is to simply prompt the user with the field name when
  ## in interactive mode, and to raise an exception if the value is not passed
  ## to #create in non-interactive mode.
  ##
  ## Options:
  ##   :interactive_generator => a method name or Proc that will be called to
  ##     return the value of this field, if the model object is created
  ##     interactively.
  ##   :generator => a method name or Proc that will be called to return the
  ##     value of this field. If the model object is created interactively, and
  ##     a :interactive_generator option is specified, that will be used instead.
  ##   :multi => a boolean determining whether the field has multiple values,
  ##     i.e., is an array. If created with :ask => false, will be initialized
  ##     to [] instead of to nil. Additionally, the model object will have
  ##     #add_<field> and #drop_<field> methods.
  ##   :ask => a boolean determining whether, if the model object is created
  ##     interactively, the user will be prompted for the value of this field.
  ##     TRUE BY DEFAULT. If :interactive_generator or :generator are specified,
  ##     those will be called instead.
  ##
  ##     If this is true, non-interactive creation
  ##     will raise an exception unless the field value is passed as an argument.
  ##     If this is false, non-interactive creation will initialize this to nil
  ##     (or [] if this field is additionally marked :multi) unless the value is
  ##     passed as an argument.
  ##  :prompt => a string to display to the user when prompting for the field
  ##    value during interactive creation. Not used if :generator or
  ##    :interactive_generator is specified.
  ##  :multiline => a boolean determining whether to prompt the user for a
  ##    multiline answer during interactive creation. Default false. Not used
  ##    if :generator or :interactive_generator is specified.
  ##  :default => a default value when prompting for the field value during
  ##    interactive creation. Not used if :generator, :interactive_generator,
  ##    :multiline, or :default_generator is specified.
  ##  :default_generator => a method name or Proc which will be called to
  ##    generate the default value when prompting for the field value during
  ##    interactive creation. Not used if :generator, :interactive_generator,
  ##    or :multiline is specified.
  ##  :nil_ok => a boolean determining whether, if created in non-interactive
  ##    mode and the value for this field is not passed in, (or is passed in
  ##    as nil), that's ok. Default is false. This is not necessary if :ask =>
  ##    false is specified; it's only necessary for fields that you want an
  ##    interactive prompt for, but a nil value is fine.
  def self.field name, opts={}
    @fields ||= [] # can't use a hash because we need to preserve field order
    raise ModelError, "field with name #{name} already defined" if @fields.any? { |k, v| k == name }
    @fields << [name, opts]

    if opts[:multi]
      single_name = name.to_s.sub(/s$/, "") # oh yeah
      define_method "add_#{single_name}" do |obj|
        array = send(name)
        raise ModelError, "already has a #{single_name} with name #{obj.name.inspect}" if obj.respond_to?(:name) && array.any? { |o| o.name == obj.name }
        changed!
        @serialized_values.delete name
        array << obj
      end

      define_method "drop_#{single_name}" do |obj|
        return unless send(name).delete obj
        @serialized_values.delete name
        changed!
        obj
      end
    end

    define_method "#{name}=" do |o|
      changed!
      @serialized_values.delete name
      @values[name] = o
    end

    define_method "__serialized_#{name}=" do |o|
      changed!
      @values.delete name
      @serialized_values[name] = o
    end

    define_method "__serialized_#{name}" do
      @serialized_values[name]
    end

    define_method name do
      return @values[name] if @values.member?(name)
      @values[name] = deserialized_form_of name, @serialized_values[name]
    end
  end

  def self.field_names; @fields.map { |name, opts| name } end
  class << self
    attr_reader :fields, :values, :serialized_values
  end

  def self.changes_are_logged
    define_method(:changes_are_logged?) { true }
    field :log_events, :multi => true, :ask => false
    define_method(:log) do |what, who, comment|
      add_log_event([Time.now, who, what, comment || ""])
      self
    end
    define_method(:last_event_time) { log_events.empty? ? nil : log_events.last[0] }
  end

  def self.from fn
    returning YAML::load_file(fn) do |o|
      raise ModelError, "error loading from yaml file #{fn.inspect}: expected a #{self}, got a #{o.class}" unless o.class == self
      o.pathname = fn if o.respond_to? :pathname=
      o.validate! :load, []
    end
  end

  def to_s
    "<#{self.class.name}: " + self.class.field_names.map { |f| "#{f}: " + send(f).inspect }.join(", ") + ">"
  end

  def inspect; to_s end

  ## depth-first search on all reachable ModelObjects. fuck yeah.
  def each_modelobject
    seen = {}
    to_see = [self]
    until to_see.empty?
      cur = to_see.pop
      seen[cur] = true
      yield cur
      cur.class.field_names.each do |f|
        val = cur.send(f)
        next if seen[val]
        if val.is_a?(ModelObject)
          to_see.push val
        elsif val.is_a?(Array)
          to_see += val.select { |v| v.is_a?(ModelObject) }
        end
      end
    end
  end

  def save! fn
    #FileUtils.mv fn, "#{fn}~", :force => true rescue nil
    File.open(fn, "w") { |f| f.puts to_yaml }
    self
  end

  def to_yaml opts={}
    ret = YAML::quick_emit(object_id, opts) do |out|
      out.map(taguri, nil) do |map|
        self.class.fields.each do |f, fops|
          v = if @serialized_values.member?(f)
            @serialized_values[f]
          else
            @serialized_values[f] = serialized_form_of f, @values[f]
          end

          map.add f.to_s, v
        end
      end
    end
    YamlWaml.decode(ret)
  end

  def changed?; @changed ||= false end
  def changed!; @changed = true end
  def unchanged!; @changed = false end

  class << self
    ## creates the object, prompting the user when necessary. can take
    ## a :with => { hash } parameter for pre-filling model fields.
    ##
    ## can also take a :defaults_from => obj parameter for pre-filling model
    ## fields from another object with (some of) those fields. kinda like a
    ## bizarre interactive copy constructor.
    def create_interactively opts={}
      o = self.new
      generator_args = opts[:args] || []
      @fields.each do |name, field_opts|
        val = if opts[:with] && opts[:with][name]
          opts[:with][name]
        else
          found, v = generate_field_value(o, field_opts, generator_args, :interactive => true)
          if found
            v
          else
            q = field_opts[:prompt] || name.to_s.capitalize
            if field_opts[:multiline]
              ## multiline options currently aren't allowed to have a default
              ## value, so just ask.
              ask_multiline_or_editor q
            else
              default = if opts[:defaults_from] && opts[:defaults_from].respond_to?(name) && (x = opts[:defaults_from].send(name))
                x
              else
                default = generate_field_default o, field_opts, generator_args
              end
              ask q, :default => default
            end
          end
        end
        o.send "#{name}=", val
      end
      o.validate! :create, generator_args
      o
    end

    ## creates the object, filling in fields from 'vals', and throwing a
    ## ModelError when it can't find all the requisite fields
    def create vals={}, generator_args=[]
      o = self.new
      @fields.each do |fname, fopts|
        val = if(x = vals[fname] || vals[fname.to_s])
          x
        else
          found, x = generate_field_value(o, fopts, generator_args, :interactive => false)
          if found
            x
          elsif !fopts[:nil_ok]
            raise ModelError, "missing required field #{fname.inspect} on #{self.name} object (got #{vals.keys.inspect})"
          end
        end
        o.send "#{fname}=", val if val
      end
      o.validate! :create, generator_args
      o
    end

  private

    ## get the value for a field if it can be automatically determined
    ## returns [success, value] (because a successful value can be nil)
    def generate_field_value o, field_opts, args, opts={}
      gen = if opts[:interactive]
        field_opts[:interactive_generator] || field_opts[:generator]
      else
        field_opts[:generator]
      end

      if gen.is_a? Proc
        [true, gen.call(*args)]
      elsif gen
        [true, o.send(gen, *args)]
      elsif field_opts[:ask] == false # nil counts as true here
        [true, field_opts[:default] || (field_opts[:multi] ? [] : nil)]
      else
        [false, nil]
      end
    end

    def generate_field_default o, field_opts, args
      if field_opts[:default_generator].is_a? Proc
        field_opts[:default_generator].call(*args)
      elsif field_opts[:default_generator]
        o.send field_opts[:default_generator], *args
      elsif field_opts[:default]
        field_opts[:default]
      end
    end
  end
end

end
