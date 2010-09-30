#!/usr/bin/env ruby
#
# Export MediaWiki pages as XML
#
require 'media_wiki/gateway'

if ARGV.length < 3
  raise "Syntax: export_xml.rb <host> <user> <password> [page page page...]"
end

mw = MediaWiki::Gateway.new(ARGV[0])
mw.login(ARGV[1], ARGV[2])
print mw.export(ARGV[3..-1])

