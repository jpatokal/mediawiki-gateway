#!/usr/bin/env ruby
#
# Sample script for uploading files to Mediawiki Commons (interactive)

require 'lib/media_wiki'

config = MediaWiki::Config.new(ARGV, "upload")
file = ARGV[0]
config.abort("Name of file to upload is mandatory.") unless file

mw = MediaWiki::Gateway.new(config.url)
mw.login(config.user, config.pw)

puts "Login successful."
puts "Description of file:"
desc = STDIN.gets.chomp
puts "Date of file:"
date = STDIN.gets.chomp
puts "Target filename: (leave blank to use existing name)"
target = STDIN.gets.chomp
target = config.target if target.empty? 
puts "Categories, separated by commas:"
cats = STDIN.gets.chomp.split(",")
cats = "[[Category:" + cats.join("]]\n[[Category:") + "]]" unless cats.empty?

template = <<-TEMPLATE
== Summary ==
{{Information
|Description={{en|1=%DESC%}}
|Source={{own}}
|Author=[[User:%USER%|%USER%]]
|Date=%DATE%
|Permission=
|other_versions=
}}

== Licensing ==
{{self|cc-by-sa-3.0|GFDL}}

%CATS%
TEMPLATE
desc = template.gsub('%USER%', config.user).gsub('%DESC%', desc).gsub('%DATE%', date).gsub('%CATS%', cats)
puts "Uploading #{file} to #{target}..."
mw.upload(file, {:target => target, :description => desc, :summary => "Uploaded by MediaWiki::Gateway"})
puts "Done."
