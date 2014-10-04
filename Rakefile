require_relative 'lib/media_wiki/version'

require "rubygems/package_task"
require 'rdoc/task'
require 'rspec/core/rake_task'

task :default => ['spec']

desc 'generate API documentation to doc/index.html'

RDoc::Task.new do |rd|
  rd.rdoc_dir = 'doc'
  rd.main = 'README'
  rd.rdoc_files.include "README", "lib/media_wiki/**/*\.rb", "script/**/*\.rb"
  rd.options << '--inline-source'
  rd.options << '--line-numbers'
  rd.options << '--all'
end

desc "Run all specs"
RSpec::Core::RakeTask.new('spec') do |t|
  t.pattern = FileList['spec/**/*.rb']
end


begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "mediawiki-gateway"
    gemspec.summary = "Connect to the mediawiki API"
    gemspec.description = ""
    gemspec.email = "jpatokal@iki.fi"
    gemspec.homepage = "http://github.com/jpatokal/mediawiki-gateway"
    gemspec.authors = ["Jani Patokallio"]
    gemspec.version = MediaWiki::VERSION
    gemspec.required_ruby_version = '>= 1.9.3'
  end
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end
