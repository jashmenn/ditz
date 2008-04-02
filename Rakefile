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

  p.description = p.paragraphs_of('README.txt', 4..5, 9..18).join("\n\n").gsub(/== SYNOPSIS/, "Synopsis")
  p.url = "http://ditz.rubyforge.org"
  p.changes = p.paragraphs_of('Changelog', 0..0).join("\n\n")
  p.email = "wmorgan-ditz@masanjin.net"
  p.extra_deps = [['trollop', '>= 1.7']]
end

WWW_FILES = FileList["www/*"] + %w(README.txt)
SCREENSHOTS = FileList["www/ss?.png"]
SCREENSHOTS_SMALL = []
SCREENSHOTS.each do |fn|
  fn =~ /ss(\d+)\.png/
  sfn = "www/ss#{$1}-small.png"
  file sfn => [fn] do |t|
    sh "cat #{fn} | pngtopnm | pnmscale -xysize 320 240 | pnmtopng > #{sfn}"
  end
  SCREENSHOTS_SMALL << sfn
end

task :upload_webpage => WWW_FILES do |t|
  sh "scp -C #{t.prerequisites * ' '} wmorgan@rubyforge.org:/var/www/gforge-projects/ditz/"
end

task :upload_webpage_images => (SCREENSHOTS + SCREENSHOTS_SMALL) do |t|
  sh "scp -C #{t.prerequisites * ' '} wmorgan@rubyforge.org:/var/www/gforge-projects/ditz/"
end

task :upload_report do |t|
  sh "ditz html ditz"
  sh "scp -Cr ditz wmorgan@rubyforge.org:/var/www/gforge-projects/ditz/"
end

# vim: syntax=ruby
