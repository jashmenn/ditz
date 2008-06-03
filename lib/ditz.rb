require 'pathname'
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

def find_project_root pwd, target
  return pwd if (pwd + target).exist?
  unless pwd.parent == pwd
    find_project_root pwd.parent, target
  end
end

def self.has_readline=(val)
  @has_readline=val
end

module_function :find_project_root
end

begin
  require 'readline'
  Ditz::has_readline=true
rescue LoadError
  # do nothing
end

require 'model-objects'
require 'operator'
require 'hook'
