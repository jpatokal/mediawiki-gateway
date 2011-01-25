require 'rake'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'spec/rake/spectask'
require 'lib/media_wiki'

task :default => ['spec']

desc 'generate API documentation to doc/index.html'

Rake::RDocTask.new do |rd|
  rd.rdoc_dir = 'doc'
  rd.main = 'README'
  rd.rdoc_files.include "README", "lib/media_wiki/**/*\.rb", "script/**/*\.rb"
  rd.options << '--inline-source'
  rd.options << '--line-numbers'
  rd.options << '--all'
end

desc "Run all specs"
Spec::Rake::SpecTask.new('spec') do |t|
  t.spec_files = FileList['spec/**/*.rb']
  t.spec_opts = ['--debugger']
  t.rcov = true
  t.rcov_opts = ['--exclude', 'spec,gems']
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
    gemspec.add_dependency 'rest-client', '>= 1.3.0'
    gemspec.add_development_dependency 'activesupport'
    gemspec.add_development_dependency 'jeweler'
    gemspec.add_development_dependency 'sham_rack'
    gemspec.add_development_dependency 'rr'
  end
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end
