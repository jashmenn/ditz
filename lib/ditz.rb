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

def find_project_root(dir, pwd)
  p = Pathname.new pwd
  np = p.join dir, "project.yaml"
  if np.exist?
    return np.dirname
  else
    if p.dirname != p
      find_project_root dir, p.dirname
    else
      return nil
    end
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
