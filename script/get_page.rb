#!/usr/bin/env ruby
#
# Sample script for fetching a page's current contents in Wiki markup
#
require 'media_wiki/gateway'

if ARGV.length < 2
  raise "Syntax: get_page.rb <host> <name>"
end

mw = MediaWiki::Gateway.new(ARGV[0])
puts mw.get(ARGV[1])
