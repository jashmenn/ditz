#!/usr/bin/env ruby

doc = {}
Dir["lib/ditz/plugins/*.rb"].each do |fn|
  name = fn =~ /([^\/]+)\.rb$/ && $1
  d = IO.read(fn) =~ /^(.+?)\n\n/m && $1
  d = d.gsub(/\A##.+\n##.*?\n/, "")
  d = d.gsub(/^## ?/, "")
  doc[name] = d
end

dockeys = doc.keys.sort
puts <<EOS
Ditz plugin documentation
-------------------------

Ditz features a code plugin system for adding and extending commands, fields,
and output. Ditz's plugin system is used to add optional functionality to Ditz.

If you're interested in writing a plugin, look at the simple plugins in
lib/ditz/plugin/, and see
  http://all-thing.net/2008/07/ditz-04-and-magic-of-ruby-dsls.html
If you're interested using plugins, read on.

Ditz loads specific plugins by looking for a .ditz-plugins file in the project
root. The format of this file is a YAML array of strings, where each string is
a plugin name. You can write this by hand like this:

  - my-plugin
  - another-plugin

I.e. one plugin name per line, prefixed by "- " as the first two characters of each line.

For each listed plugin name, Ditz looks for a file named
"lib/ditz/plugin/<name>.rb" within Ruby's default search path. Assuming Ditz is
installed in a standard manner, you should have available to you the following
shipped plugins:

EOS
dockeys.each_with_index do |p, i|
  puts "#{i + 1}. #{p}"
end

puts

dockeys.each do |p|
  puts p
  puts "-" * p.size 
  puts
  puts doc[p]
  puts
end
