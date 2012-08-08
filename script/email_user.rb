#!/usr/bin/env ruby
#
# Sample script for sending e-mail to a registered user
#
require './lib/media_wiki'

config = MediaWiki::Config.new ARGV
user, subject = ARGV
config.abort("Syntax: email_user.rb [username] [subject] <content") unless user and subject

mw = MediaWiki::Gateway.new(config.url, { :loglevel => Logger::DEBUG } )
mw.login(config.user, config.pw)
content = STDIN.read
mw.email_user(user, subject, content)
