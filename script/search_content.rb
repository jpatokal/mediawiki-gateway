#!/usr/bin/env ruby
#
# Sample script for searching page contents in a Wiki
#
require 'lib/media_wiki'

config = MediaWiki::Config.new ARGV 
config.abort("Please specify search key as article name (-a)") unless config.article

mw = MediaWiki::Gateway.new(config.url, { :loglevel => Logger::DEBUG } )
mw.login(config.user, config.pw)
puts mw.search(config.article, nil, 50)
