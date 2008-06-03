module Ditz

VERSION = "0.2"

def debug s
  puts "# #{s}" if $opts[:verbose]
end
module_function :debug

def self.has_readline?
  @has_readline
end

def self.has_readline= val
  @has_readline = val
end
end

begin
  Ditz::has_readline = false
  require 'readline'
  Ditz::has_readline = true
rescue LoadError
  # do nothing
end

require 'model-objects'
require 'operator'
require 'hook'
