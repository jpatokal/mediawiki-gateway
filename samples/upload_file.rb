#!/usr/bin/env ruby
#
# Sample script for fetching a page's current contents in Wiki markup
#
require './lib/media_wiki'

config = MediaWiki::Config.new(ARGV, "upload")
config.abort("Name of file to upload is mandatory.") unless ARGV[0]

mw = MediaWiki::Gateway.new(config.url, { :loglevel => Logger::DEBUG } )
mw.login(config.user, config.pw)
mw.upload(ARGV[0], {:target => config.target, :description => config.desc, :summary => config.summary})

