#!/usr/bin/env ruby
#
# Import a MediaWiki XML dump 
#
require './lib/media_wiki'

if ARGV.length < 3
  raise "Syntax: import_xml.rb <host> <username> <password> <file>"
end

mw = MediaWiki::Gateway.new(ARGV[0], Logger::DEBUG)
mw.login(ARGV[1], ARGV[2])
mw.import(ARGV[3])

