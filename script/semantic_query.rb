#!/usr/bin/env ruby
#
# Sample script for querying Semantic MediaWiki data
#

require './lib/media_wiki'

mw = MediaWiki::Gateway.new(ARGV[0])

params = []
i = 2
until i == ARGV.length
	params << ARGV[i]
	i += 1
end

puts mw.semantic_query(ARGV[1], params)
