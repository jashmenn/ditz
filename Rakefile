require 'rubygems'
require 'hoe'

$:.unshift "lib"
require 'ditz'

class Hoe
  def extra_deps; @extra_deps.reject { |x| Array(x).first == "hoe" } end
end # thanks to "Mike H"

Hoe.new('ditz', Ditz::VERSION) do |p|
  p.rubyforge_name = 'ditz'
  p.author = "William Morgan"
  p.summary = "A simple issue tracker designed to integrate well with distributed version control systems like git and darcs. State is saved to a YAML file kept under version control, allowing issues to be closed/added/modified as part of a commit."

  p.description = p.paragraphs_of('README.txt', 4..11).join("\n\n").gsub(/== SYNOPSIS/, "Synopsis:")
  p.url = "http://ditz.rubyforge.org"
  p.changes = p.paragraphs_of('Changelog', 0..0).join("\n\n")
  p.email = "wmorgan-ditz@masanjin.net"
  p.extra_deps = [['trollop', '>= 1.8.2']]
end

WWW_FILES = FileList["www/*"] + %w(README.txt PLUGINS.txt)

task :upload_webpage => WWW_FILES do |t|
  sh "rsync -essh -cavz #{t.prerequisites * ' '} wmorgan@rubyforge.org:/var/www/gforge-projects/ditz/"
end

task :upload_report do |t|
  sh "ruby -Ilib bin/ditz html ditz"
  sh "rsync -essh -cavz ditz wmorgan@rubyforge.org:/var/www/gforge-projects/ditz/"
end

task :plugins  do |t|
  sh "ruby -w ./make-plugins.txt.rb > PLUGINS.txt"
end

# vim: syntax=ruby
