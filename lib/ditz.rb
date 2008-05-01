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

def find_project_root(pwd, project_root, dir)
  np = pwd.join project_root, dir, "project.yaml"
  if np.exist?
    return project_root
  else
    if pwd + project_root != pwd + project_root.parent
      find_project_root pwd, project_root.parent, dir
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
require 'hook'
