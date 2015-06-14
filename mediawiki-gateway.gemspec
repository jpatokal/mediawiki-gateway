# -*- encoding: utf-8 -*-
# stub: mediawiki-gateway 1.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "mediawiki-gateway"
  s.version = "1.0.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Jani Patokallio", "Jens Wille"]
  s.date = "2014-10-31"
  s.description = "A Ruby framework for MediaWiki API manipulation."
  s.email = ["jpatokal@iki.fi", "jens.wille@gmail.com"]
  s.executables = ["mediawiki-gateway"]
  s.extra_rdoc_files = ["COPYING", "ChangeLog", "README.md"]
  s.files = ["COPYING", "ChangeLog", "README.md", "Rakefile", "bin/mediawiki-gateway", "lib/media_wiki.rb", "lib/media_wiki/exception.rb", "lib/media_wiki/fake_wiki.rb", "lib/media_wiki/gateway.rb", "lib/media_wiki/gateway/files.rb", "lib/media_wiki/gateway/pages.rb", "lib/media_wiki/gateway/query.rb", "lib/media_wiki/gateway/site.rb", "lib/media_wiki/gateway/users.rb", "lib/media_wiki/utils.rb", "lib/media_wiki/version.rb", "lib/mediawiki-gateway.rb", "spec/data/import.xml", "spec/media_wiki/gateway/files_spec.rb", "spec/media_wiki/gateway/pages_spec.rb", "spec/media_wiki/gateway/query_spec.rb", "spec/media_wiki/gateway/site_spec.rb", "spec/media_wiki/gateway/users_spec.rb", "spec/media_wiki/gateway_spec.rb", "spec/media_wiki/live_gateway_spec.rb", "spec/media_wiki/utils_spec.rb", "spec/spec_helper.rb"]
  s.homepage = "http://github.com/jpatokal/mediawiki-gateway"
  s.licenses = ["MIT"]
  s.post_install_message = "\nmediawiki-gateway-1.0.0 [2014-10-31]:\n\n* <b>Required Ruby version is now 1.9.3 or higher.</b>\n* For better Unicode support, install the +unicode+ or +activesupport+ gem.\n* API methods are grouped into submodules of MediaWiki::Gateway.\n* MediaWiki::Utils has been added as a proper module.\n* MediaWiki::FakeWiki has been added as a first-class citizen.\n* MediaWiki::Config has been removed.\n* MediaWiki::Gateway#send_request allows generic API requests.\n* MediaWiki::Gateway::Query#custom_query has been made public.\n* MediaWiki::Gateway::new learned +user_agent+ option.\n* MediaWiki::Gateway#headers attribute has been exposed.\n* MediaWiki::Gateway#wiki_url attribute has been exposed.\n* Added +mediawiki-gateway+ command-line client.\n* Changed or removed some of the dependencies.\n* Housekeeping and internal refactoring.\n\n"
  s.rdoc_options = ["--title", "mediawiki-gateway Application documentation (v1.0.0)", "--charset", "UTF-8", "--line-numbers", "--all", "--main", "README.md"]
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
      s.add_development_dependency(%q<hen>, [">= 0.8.0", "~> 0.8"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<rspec>, [">= 0"])
    else
      s.add_dependency(%q<rest-client>, ["~> 1.7"])
      s.add_dependency(%q<equivalent-xml>, [">= 0"])
      s.add_dependency(%q<nokogiri>, [">= 0"])
      s.add_dependency(%q<sham_rack>, [">= 0"])
      s.add_dependency(%q<sinatra>, [">= 0"])
      s.add_dependency(%q<hen>, [">= 0.8.0", "~> 0.8"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<rspec>, [">= 0"])
    end
  else
    s.add_dependency(%q<rest-client>, ["~> 1.7"])
    s.add_dependency(%q<equivalent-xml>, [">= 0"])
    s.add_dependency(%q<nokogiri>, [">= 0"])
    s.add_dependency(%q<sham_rack>, [">= 0"])
    s.add_dependency(%q<sinatra>, [">= 0"])
    s.add_dependency(%q<hen>, [">= 0.8.0", "~> 0.8"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<rspec>, [">= 0"])
  end
end
