module Ditz
  class HookManager
    def initialize
      @descs = {}
      @blocks = {}
    end

    @@instance = nil
    def self.method_missing m, *a, &b
      @@instance ||= self.new
      @@instance.send m, *a, &b
    end

    def register name, desc
      @descs[name] = desc
      @blocks[name] = []
    end

    def on *names, &block
      names.each do |name|
        raise "unregistered hook #{name.inspect}" unless @descs[name]
        @blocks[name] << block
      end
    end

    def run name, *args
      raise "unregistered hook #{name.inspect}" unless @descs[name]
      blocks = hooks_for name
      return false if blocks.empty?
      blocks.each { |block| block[*args] }
      true
    end

    def print_hooks f=$stdout
puts <<EOS
Ditz has #{@descs.size} registered hooks:

EOS

      @descs.map{ |k,v| [k.to_s,v] }.sort.each do |name, desc|
        f.puts <<EOS
#{name}
#{"-" * name.length}
#{desc}
EOS
      end
    end

    def enabled? name; !hooks_for(name).empty? end

    def hooks_for name
      if @blocks[name].nil? || @blocks[name].empty?
        fns = File.join(ENV['HOME'], '.ditz', 'hooks', '*.rb') 
        Dir[fns].each { |fn| load fn }
      end

      @blocks[name] || []
    end
  end
end
