require 'pathname'

module Ditz

VERSION = "0.5"
attr_accessor :verbose
module_function :verbose, :verbose=

def debug s
  puts "# #{s}" if $verbose || Ditz::verbose
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

def load_plugins fn
  Ditz::debug "loading plugins from #{fn}"
  plugins = YAML::load_file fn
  plugins.each do |p|
    fn = Ditz::find_ditz_file "ditz/plugins/#{p}.rb"
    Ditz::debug "loading plugin #{p.inspect} from #{fn}"
    require File.expand_path(fn)
  end
  plugins
end

module_function :home_dir, :find_dir_containing, :find_ditz_file, :load_plugins
end

# Git-style automatic pagination of all output.
# Call run_pa	ger from any opperator needing pagination.
# Yoinked from http://nex-3.com/posts/73-git-style-automatic-paging-in-ruby#comments
def run_pager
  return if PLATFORM =~ /win32/
  return unless STDOUT.tty?

  read, write = IO.pipe

  unless Kernel.fork # Child process
    STDOUT.reopen(write)
    STDERR.reopen(write) if STDERR.tty?
    read.close
    write.close
    return
  end

  # Parent process, become pager
  STDIN.reopen(read)
  read.close
  write.close

  ENV['LESS'] = 'FSRX' # Don't page if the input is short enough

  Kernel.select [STDIN] # Wait until we have input before we start the pager
  pager = ENV['PAGER'] || 'less'
  exec pager rescue exec "/bin/sh", "-c", pager
end

require 'ditz/model-objects'
require 'ditz/operator'
require 'ditz/views'
require 'ditz/hook'
require 'ditz/file-storage'
