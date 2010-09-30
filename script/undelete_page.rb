#!/usr/bin/env ruby
require File.dirname(__FILE__) + '/../../config/environment'

if ARGV.length <1
  raise "Syntax: undelete.rb <initial-pattern> [environment]\n  Sample: undelete.rb 'Book:Shanghai 5' devint"
end

host = ARGV[1] ? "webvip.mediawiki.#{ARGV[1]}.lpo" : LonelyPlanet::OnRails.environment.services[:atlas_mediawiki]
rw = MediaWiki::Gateway.new(host)
rw.login('atlasmw', 'wombat')
# Warning: List only works on existing pages (deleted & reimported), there's a separate unimplemented op for listing currently deleted pages
rw.list(ARGV[0]).each do |title|
  print "Undeleting #{title}... #{rw.undelete(title)} revisions restored.\n"
end
print "Done."
