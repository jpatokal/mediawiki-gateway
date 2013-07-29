#!/usr/bin/env ruby
#
# Sample script for updating a MediaWiki article's content
#
require './lib/media_wiki'

config = MediaWiki::Config.new ARGV 
config.abort("Name of article is mandatory.") unless config.article

mw = MediaWiki::Gateway.new(config.url, { :loglevel => Logger::DEBUG } )
mw.login(config.user, config.pw)
content = ARGF.read.to_s
puts mw.create(config.article, content, {:overwrite => true, :summary => config.summary})
