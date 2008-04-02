require 'yaml'
require "lowline"; include Lowline
require "util"
require 'sha1'

module Ditz

class ModelObject
  class ModelError < StandardError; end

  ## yamlability
  def self.yaml_domain; "ditz.rubyforge.org,2008-03-06" end
  def self.yaml_other_thing; name.split('::').last.dcfirst end
  def to_yaml_type; "!#{self.class.yaml_domain}/#{self.class.yaml_other_thing}" end
  def to_yaml_properties; self.class.fields.map { |f| "@#{f.to_s}" } end
  def self.inherited subclass
    YAML.add_domain_type(yaml_domain, subclass.yaml_other_thing) do |type, val|
      YAML.object_maker(subclass, val)
    end
  end
  def before_serialize(*a); end
  def after_deserialize(*a); end

  def self.field name, opts={}
    @fields ||= [] # can't use a hash because want to preserve field order when serialized
    raise ModelError, "field with name #{name} already defined" if @fields.any? { |k, v| k == name }
    @fields << [name, opts]

    attr_reader name
    if opts[:multi]
      single_name = name.to_s.sub(/s$/, "") # oh yeah
      define_method "add_#{single_name}" do |obj|
        array = self.instance_variable_get("@#{name}")
        raise ModelError, "already has a #{single_name} with name #{obj.name.inspect}" if obj.respond_to?(:name) && array.any? { |o| o.name == obj.name }
        changed!
        array << obj
      end

      define_method "drop_#{single_name}" do |obj|
        return unless self.instance_variable_get("@#{name}").delete obj
        changed!
        obj
      end
    end
    define_method "#{name}=" do |o|
      changed!
      instance_variable_set "@#{name}", o
    end
  end

  def self.fields; @fields.map { |name, opts| name } end

  def self.changes_are_logged
    define_method(:changes_are_logged?) { true }
    field :log_events, :multi => true, :ask => false
  end

  def self.from fn
    returning YAML::load_file(fn) do |o|
      raise ModelError, "error loading from yaml file #{fn.inspect}: expected a #{self}, got a #{o.class}" unless o.class == self
    end
  end

  ## depth-first search on all reachable ModelObjects. fuck yeah.
  def each_modelobject
    seen = {}
    to_see = [self]
    until to_see.empty?
      cur = to_see.pop
      seen[cur] = true
      yield cur
      cur.class.fields.each do |f|
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
    Ditz::debug "saving configuration to #{fn}"
    FileUtils.mv fn, "#{fn}~", :force => true rescue nil
    File.open(fn, "w") { |f| f.puts to_yaml }
  end

  def log what, who, comment
    add_log_event([Time.now, who, what, comment])
    self
  end

  def initialize
    @changed = false
    @log_events = []
  end

  def changed?; @changed end
  def changed!; @changed = true end

  def self.create_interactively opts={}
    o = self.new
    args = opts[:args] || []
    @fields.each do |name, field_opts|
      val = if opts[:with] && opts[:with][name]
        opts[:with][name]
      elsif field_opts[:generator].is_a? Proc
        field_opts[:generator].call(*args)
      elsif field_opts[:generator]
        o.send field_opts[:generator], *args
      elsif field_opts[:ask] == false # nil counts as true here
        field_opts[:default] || (field_opts[:multi] ? [] : nil)
      else
        q = field_opts[:prompt] || name.to_s.ucfirst
        if field_opts[:multiline]
          ask_multiline q
        else
          default = if field_opts[:default_generator].is_a? Proc
            field_opts[:default_generator].call(*args)
          elsif field_opts[:default_generator]
            o.send field_opts[:default_generator], *args
          elsif field_opts[:default]
            field_opts[:default]
          end
            
          ask q, :default => default
        end
      end
      o.send("#{name}=", val)
    end
    o
  end
end

end
