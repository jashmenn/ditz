module Ditz

VERSION = "0.2"
@has_readline=false

def debug s
  puts "# #{s}" if $opts[:verbose]
end
module_function :debug

def self.has_readline?
  @has_readline
end

def self.has_readline=(val)
  @has_readline=val
end

end

begin
  require 'readline'
  Ditz::has_readline=true
rescue LoadError
  # do nothing
end

require 'model-objects'
require 'operator'
