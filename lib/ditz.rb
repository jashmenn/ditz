require 'pathname'
module Ditz

VERSION = "0.2"

def debug s
  puts "# #{s}" if $opts[:verbose]
end
module_function :debug


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

module_function :find_project_root

end

require 'model-objects'
require 'operator'
