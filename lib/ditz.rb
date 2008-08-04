module Ditz

VERSION = "0.4"

def debug s
  puts "# #{s}" if $verbose
end
module_function :debug

def self.has_readline?
  @has_readline
end

def self.has_readline= val
  @has_readline = val
end

begin
  Ditz::has_readline = false
  require 'readline'
  Ditz::has_readline = true
rescue LoadError
  # do nothing
end

def home_dir
  @home ||=
    ENV["HOME"] || (ENV["HOMEDRIVE"] && ENV["HOMEPATH"] ? ENV["HOMEDRIVE"] + ENV["HOMEPATH"] : nil) || begin
    $stderr.puts "warning: can't determine home directory, using '.'"
    "."
  end
end

## helper for recursive search
def find_dir_containing target, start=Pathname.new(".")
  return start if (start + target).exist?
  unless start.parent.realpath == start.realpath
    find_dir_containing target, start.parent
  end
end

## my brilliant solution to the 'gem datadir' problem
def find_ditz_file fn
  dir = $:.find { |p| File.exist? File.expand_path(File.join(p, fn)) }
  raise "can't find #{fn} in any load path" unless dir
  File.expand_path File.join(dir, fn)
end

module_function :home_dir, :find_dir_containing, :find_ditz_file
end

require 'model-objects'
require 'operator'
require 'views'
require 'hook'
require 'file-storage'

