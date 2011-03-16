require 'rubygems'
require 'hoe'

$:.unshift "lib"
require 'ditz'

class Hoe
  def extra_dev_deps; @extra_dev_deps.reject { |x| x[0] == "hoe" } end
end

Hoe.new('ditz', Ditz::VERSION) do |p|
  p.rubyforge_name = 'ditz'
  p.author = "William Morgan"
  p.summary = "A simple issue tracker designed to integrate well with distributed version control systems like git and darcs. State is saved to a YAML file kept under version control, allowing issues to be closed/added/modified as part of a commit."

  p.description = p.paragraphs_of('README.txt', 4..11).join("\n\n").gsub(/== SYNOPSIS/, "Synopsis:")
  p.url = "http://ditz.rubyforge.org"
  p.changes = p.paragraphs_of('Changelog', 0..0).join("\n\n")
  p.email = "wmorgan-ditz@masanjin.net"
  p.extra_deps = [['trollop', '>= 1.9'], ['yaml_waml', '>= 0.3']]
end

WWW_FILES = FileList["www/*"] + %w(README.txt PLUGINS.txt)

task :upload_webpage => WWW_FILES do |t|
  sh "rsync -essh -cavz #{t.prerequisites * ' '} mattkatz@rubyforge.org:/var/www/gforge-projects/ditz/"
end

task :upload_report do |t|
  sh "ruby -Ilib bin/ditz html ditz"
  sh "rsync -essh -cavz ditz mattkatz@rubyforge.org:/var/www/gforge-projects/ditz/"
end

task :plugins  do |t|
  sh "ruby -w ./make-plugins.txt.rb > PLUGINS.txt"
end

task :really_check_manifest do |t|
  f1 = Tempfile.new "manifest"; f1.close
  f2 = Tempfile.new "manifest"; f2.close
  sh "git ls-files | egrep -v \"^.ditz/\" | sort > #{f1.path}"
  sh "sort Manifest.txt > #{f2.path}"

  f3 = Tempfile.new "manifest"; f3.close
  sh "diff -u #{f1.path} #{f2.path} > #{f3.path}; /bin/true"

  left, right = [], []
  IO.foreach(f3.path) do |l|
    case l
    when /^\-\-\-/
    when /^\+\+\+/
    when /^\-(.*)\n$/; left << $1
    when /^\+(.*)\n$/; right << $2
    end
  end

  puts
  puts "Tracked by git but not in Manifest.txt:"
  puts left.empty? ? "  <nothing>" : left.map { |l| "  " + l }

  puts
  puts "In Manifest.txt, but not tracked by git:"
  puts right.empty? ? "  <nothing>" : right.map { |l| "  " + l }
end

# vim: syntax=ruby
