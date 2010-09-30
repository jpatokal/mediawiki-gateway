#!/usr/bin/env ruby
require 'media_wiki/gateway'

if ARGV.length <1
  raise "Syntax: delete_batch.rb <wiki-api-url> <startswith_pattern>"
end

rw = MediaWiki::Gateway.new(ARGV[0])
rw.list(ARGV[1]).each do |title|
  print "Deleting #{title}..."
  rw.delete(title)
end
print "Done."

