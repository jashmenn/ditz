require 'yaml'
require 'sha1'
require "ditz/lowline"; include Lowline
require "ditz/util"

class Time
  alias :old_to_yaml :to_yaml
  def to_yaml(opts = {})
    self.utc.old_to_yaml(opts)
  end
end

module Ditz

class ModelObject
  class ModelError < StandardError; end

  def initialize
    @values = {}
    @serialized_values = {}
    self.class.fields.map { |f, opts| @values[f] = [] if opts[:multi] }
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
      o.unchanged!
      o
    end
  end

  ## override these two to model per-field transformations between disk and
  ## memory.
  ##
  ## convert disk form => memory form
  def deserialized_form_of field, value
    @serialized_values[field]
  end

  ## convert memory form => disk form
  def serialized_form_of field, value
    @values[field]
  end

  ## add a new field to a model object
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
        return unless @values[name].delete obj
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
  end

  def self.from fn
    returning YAML::load_file(fn) do |o|
      raise ModelError, "error loading from yaml file #{fn.inspect}: expected a #{self}, got a #{o.class}" unless o.class == self
      o.pathname = fn if o.respond_to? :pathname=

      o.class.fields.each do |f, opts|
        m = "__serialized_#{f}"
        if opts[:multi] && o.send(m).nil?
          $stderr.puts "Warning: corrected nil multi-field #{f}"
          o.send "#{m}=", []
        end
      end
    end
  end

  def to_s
    "<#{self.class.name}: " + self.class.field_names.map { |f| "#{f}: " + (@values[f].to_s || @serialized_values[f]).inspect }.join(", ") + ">"
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
    YAML::quick_emit(object_id, opts) do |out|
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
  end

  def log what, who, comment
    add_log_event([Time.now, who, what, comment || ""])
    self
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
        elsif(found, x = generate_field_value(o, field_opts, generator_args)) && found
          x
        else
          q = field_opts[:prompt] || name.to_s.capitalize
          if field_opts[:multiline]
            ## multiline options currently aren't allowed to have a default
            ## value, so just ask.
            ask_multiline q
          else
            default = if opts[:defaults_from] && opts[:defaults_from].respond_to?(name) && (x = opts[:defaults_from].send(name))
              x
            else
              default = generate_field_default o, field_opts, generator_args
            end
            ask q, :default => default
          end
        end
        o.send "#{name}=", val
      end
      o
    end

    ## creates the object, filling in fields from 'vals', and throwing a
    ## ModelError when it can't find all the requisite fields
    def create generator_args, vals={}
      o = self.new
      @fields.each do |name, opts|
        val = if vals[name]
          vals[name]
        elsif(found, x = generate_field_value(o, opts, generator_args)) && found
          x
        else
          raise ModelError, "missing required field #{name}"
        end
        o.send "#{name}=", val
      end
      o
    end

  private

    ## get the value for a field if it can be automatically determined
    ## returns [success, value] (because a successful value can be ni)
    def generate_field_value o, opts, args
      if opts[:generator].is_a? Proc
        [true, opts[:generator].call(*args)]
      elsif opts[:generator]
        [true, o.send(opts[:generator], *args)]
      elsif opts[:ask] == false # nil counts as true here
        [true, opts[:default] || (opts[:multi] ? [] : nil)]
      else
        [false, nil]
      end
    end

    def generate_field_default o, opts, args
      if opts[:default_generator].is_a? Proc
        opts[:default_generator].call(*args)
      elsif opts[:default_generator]
        o.send opts[:default_generator], *args
      elsif opts[:default]
        opts[:default]
      end
    end
  end
end

end
