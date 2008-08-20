#!/usr/bin/env ruby

doc = {}
Dir["lib/plugins/*.rb"].each do |fn|
  name = fn =~ /([^\/]+)\.rb$/ && $1
  d = IO.read(fn) =~ /^(.+?)\n\n/m && $1
  d = d.gsub(/\A##.+\n##.*?\n/, "")
  d = d.gsub(/^## ?/, "")
  doc[name] = d
end

dockeys = doc.keys.sort
puts <<EOS
Ditz plugin documentation

Shipped plugins:
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
