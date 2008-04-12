module Ditz
  module HookManager
    module_function

    @@descs = {}
    @@blocks = {}

    def register name, desc
      raise "Ditz::HookManager.register needs a symbol not #{name.inspect}" unless name.is_a? Symbol
      @@descs[name] = desc
      @@blocks[name] = []
    end

    def on name, &block
      raise "unregistered hook #{name.inspect}" unless @@descs[name]
      @@blocks[name] << block
    end

    def run name, *args
      raise "unregistered hook #{name.inspect}" unless @@descs[name]
      blocks = hooks_for name
      return false if blocks.empty?
      for block in blocks do
        block[*args]
      end
      true
    end

    def print_hooks f=$stdout
puts <<EOS
Ditz have #{@@descs.size} registered hooks:

EOS

      @@descs.map{ |k,v| [k.to_s,v] }.sort.each do |(name, desc)|
        f.puts <<EOS
#{name}
#{"-" * name.length}
#{desc}
EOS
      end
    end

    def enabled? name; !hooks_for(name).empty? end

    def hooks_for name
      if @@blocks[name].nil? || @@blocks[name].empty?
        fns = File.join(ENV['HOME'], '.ditz', 'hooks', '*.rb') 
        Dir[fns].each { |fn| load fn }
      end

      @@blocks[name] || []
    end
  end

end
