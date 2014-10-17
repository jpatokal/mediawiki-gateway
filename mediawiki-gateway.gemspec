# -*- encoding: utf-8 -*-
# stub: mediawiki-gateway 0.6.2 ruby lib

Gem::Specification.new do |s|
  s.name = "mediawiki-gateway"
  s.version = "0.6.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Jani Patokallio", "Jens Wille"]
  s.date = "2014-10-17"
  s.description = "A Ruby framework for MediaWiki API manipulation."
  s.email = ["jpatokal@iki.fi", "jens.wille@gmail.com"]
  s.extra_rdoc_files = ["COPYING", "ChangeLog", "README.md"]
  s.files = ["COPYING", "ChangeLog", "README.md", "Rakefile", "lib/media_wiki.rb", "lib/media_wiki/config.rb", "lib/media_wiki/exception.rb", "lib/media_wiki/gateway.rb", "lib/media_wiki/gateway/files.rb", "lib/media_wiki/gateway/pages.rb", "lib/media_wiki/gateway/query.rb", "lib/media_wiki/gateway/site.rb", "lib/media_wiki/gateway/users.rb", "lib/media_wiki/utils.rb", "lib/media_wiki/version.rb", "lib/mediawiki-gateway.rb", "spec/fake_media_wiki/api_pages.rb", "spec/fake_media_wiki/app.rb", "spec/fake_media_wiki/query_handling.rb", "spec/gateway_spec.rb", "spec/import-test-data.xml", "spec/live_gateway_spec.rb", "spec/spec_helper.rb", "spec/utils_spec.rb"]
  s.homepage = "http://github.com/jpatokal/mediawiki-gateway"
  s.licenses = ["MIT"]
  s.rdoc_options = ["--title", "mediawiki-gateway Application documentation (v0.6.2)", "--charset", "UTF-8", "--line-numbers", "--all", "--main", "README.md"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")
  s.rubygems_version = "2.4.2"
  s.summary = "Connect to the MediaWiki API."

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rest-client>, ["~> 1.7"])
      s.add_development_dependency(%q<equivalent-xml>, [">= 0"])
      s.add_development_dependency(%q<nokogiri>, [">= 0"])
      s.add_development_dependency(%q<sham_rack>, [">= 0"])
      s.add_development_dependency(%q<sinatra>, [">= 0"])
      s.add_development_dependency(%q<hen>, [">= 0.7.1", "~> 0.7"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<rspec>, [">= 0"])
    else
      s.add_dependency(%q<rest-client>, ["~> 1.7"])
      s.add_dependency(%q<equivalent-xml>, [">= 0"])
      s.add_dependency(%q<nokogiri>, [">= 0"])
      s.add_dependency(%q<sham_rack>, [">= 0"])
      s.add_dependency(%q<sinatra>, [">= 0"])
      s.add_dependency(%q<hen>, [">= 0.7.1", "~> 0.7"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<rspec>, [">= 0"])
    end
  else
    s.add_dependency(%q<rest-client>, ["~> 1.7"])
    s.add_dependency(%q<equivalent-xml>, [">= 0"])
    s.add_dependency(%q<nokogiri>, [">= 0"])
    s.add_dependency(%q<sham_rack>, [">= 0"])
    s.add_dependency(%q<sinatra>, [">= 0"])
    s.add_dependency(%q<hen>, [">= 0.7.1", "~> 0.7"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<rspec>, [">= 0"])
  end
end
