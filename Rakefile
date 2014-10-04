require_relative 'lib/media_wiki/version'

require 'rdoc/task'
require 'rspec/core/rake_task'
require 'rubygems/package_task'

task default: :spec

desc 'generate API documentation to doc/index.html'
RDoc::Task.new { |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.main = 'README.md'
  rdoc.options << '--line-numbers' << '--all'
  rdoc.rdoc_files.include(rdoc.main, 'lib/**/*.rb')
}

desc 'Run all specs'
RSpec::Core::RakeTask.new('spec') { |t|
  t.pattern = FileList['spec/**/*.rb']
}

begin
  require 'jeweler'

  Jeweler::Tasks.new { |gemspec|
    gemspec.name = 'mediawiki-gateway'
    gemspec.summary = 'Connect to the mediawiki API'
    gemspec.description = ''
    gemspec.email = 'jpatokal@iki.fi'
    gemspec.homepage = 'http://github.com/jpatokal/mediawiki-gateway'
    gemspec.authors = ['Jani Patokallio']
    gemspec.version = MediaWiki::VERSION
    gemspec.required_ruby_version = '>= 1.9.3'
  }
rescue LoadError
  puts 'Jeweler not available. Install it with: gem install jeweler'
end
