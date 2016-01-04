# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "mediawiki-gateway"
  s.version = "1.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jani Patokallio", "Jens Wille"]
  s.date = "2016-01-04"
  s.description = "A Ruby framework for MediaWiki API manipulation."
  s.email = ["jpatokal@iki.fi", "jens.wille@gmail.com"]
  s.executables = ["mediawiki-gateway"]
  s.extra_rdoc_files = ["COPYING", "ChangeLog", "README.md"]
  s.files = ["lib/media_wiki.rb", "lib/media_wiki/exception.rb", "lib/media_wiki/fake_wiki.rb", "lib/media_wiki/gateway.rb", "lib/media_wiki/gateway/files.rb", "lib/media_wiki/gateway/pages.rb", "lib/media_wiki/gateway/query.rb", "lib/media_wiki/gateway/site.rb", "lib/media_wiki/gateway/users.rb", "lib/media_wiki/utils.rb", "lib/media_wiki/version.rb", "lib/mediawiki-gateway.rb", "bin/mediawiki-gateway", "COPYING", "ChangeLog", "README.md", "Rakefile", "spec/data/import.xml", "spec/media_wiki/gateway/files_spec.rb", "spec/media_wiki/gateway/pages_spec.rb", "spec/media_wiki/gateway/query_spec.rb", "spec/media_wiki/gateway/site_spec.rb", "spec/media_wiki/gateway/users_spec.rb", "spec/media_wiki/gateway_spec.rb", "spec/media_wiki/live_gateway_spec.rb", "spec/media_wiki/utils_spec.rb", "spec/spec_helper.rb"]
  s.homepage = "http://github.com/jpatokal/mediawiki-gateway"
  s.licenses = ["MIT"]
  s.post_install_message = "\nmediawiki-gateway-1.1.0 [2016-01-05]:\n\n* Allow empty params for semantic_query.\n* Add a method to purge a page.  Pull request #93 by MusikAnimal.\n* Follow redirects if HTTP 301, 302 or 307 is returned.  Pull request #86\n  by Brandon Liu.\n* Change exception superclass to StandardError.  Pull request #85 by\n  Brandon Liu.\n* Fixed categorymembers to use new continue rules. Pull request #82\n  by Asaf Bartov.\n* Fix search to return nil if namespace not found.  Pull request #88 by\n  Alexander Adrianov. \n* Fixed MediaWiki::Gateway::Users#contributions to not continue when enough\n  contributions have been received. Pull request #79 by Micha\u{eb}l Witrant.\n\n"
  s.rdoc_options = ["--title", "mediawiki-gateway Application documentation (v1.1.0)", "--charset", "UTF-8", "--line-numbers", "--all", "--main", "README.md"]
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")
  s.rubygems_version = "2.0.14"
  s.summary = "Connect to the MediaWiki API."

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rest-client>, ["~> 1.7"])
      s.add_development_dependency(%q<equivalent-xml>, [">= 0"])
      s.add_development_dependency(%q<nokogiri>, [">= 0"])
      s.add_development_dependency(%q<sham_rack>, [">= 0"])
      s.add_development_dependency(%q<sinatra>, [">= 0"])
      s.add_development_dependency(%q<hen>, [">= 0.8.3", "~> 0.8"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<rspec>, [">= 0"])
    else
      s.add_dependency(%q<rest-client>, ["~> 1.7"])
      s.add_dependency(%q<equivalent-xml>, [">= 0"])
      s.add_dependency(%q<nokogiri>, [">= 0"])
      s.add_dependency(%q<sham_rack>, [">= 0"])
      s.add_dependency(%q<sinatra>, [">= 0"])
      s.add_dependency(%q<hen>, [">= 0.8.3", "~> 0.8"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<rspec>, [">= 0"])
    end
  else
    s.add_dependency(%q<rest-client>, ["~> 1.7"])
    s.add_dependency(%q<equivalent-xml>, [">= 0"])
    s.add_dependency(%q<nokogiri>, [">= 0"])
    s.add_dependency(%q<sham_rack>, [">= 0"])
    s.add_dependency(%q<sinatra>, [">= 0"])
    s.add_dependency(%q<hen>, [">= 0.8.3", "~> 0.8"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<rspec>, [">= 0"])
  end
end
