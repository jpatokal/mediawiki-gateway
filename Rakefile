require 'rake'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'spec/rake/spectask'

task :default => ['spec']

desc 'generate API documentation to doc/index.html'

Rake::RDocTask.new do |rd|
  rd.rdoc_dir = 'doc'
  rd.main = 'README.txt'
  rd.rdoc_files.include "README.txt", "lib/media_wiki/**/*\.rb", "script/**/*\.rb"
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

spec = Gem::Specification.new do |s| 
  s.name = "MediaWikiGateway"
  s.version = "0.0.1"
  s.author = "Jani Patokallio/Lonely Planet"
  s.email = "jpatokal@iki.fi"
  s.homepage = "http://github.com/jpatokal"
  s.platform = Gem::Platform::RUBY
  s.summary = "Ruby framework for MediaWiki API manipulation"
  s.files = FileList["{bin,lib}/**/*"].to_a
  s.require_path = "lib"
  s.autorequire = "name"
  s.test_files = FileList["{spec}/**/*.rb"].to_a
  s.has_rdoc = true
  s.extra_rdoc_files = ["README"]
end
Rake::GemPackageTask.new(spec) do |pkg| 
  pkg.need_tar = true 
end 

