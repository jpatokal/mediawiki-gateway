#!/usr/bin/env ruby
#
# Export MediaWiki pages as XML
#
require 'lib/media_wiki'

if ARGV.length < 3
  raise "Syntax: export_xml.rb <host> <user> <password> [page page page...]"
end

mw = MediaWiki::Gateway.new(ARGV[0])
mw.login(ARGV[1], ARGV[2])
print mw.export(ARGV[3..-1])

