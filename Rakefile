require_relative 'lib/media_wiki/version'

begin
  require 'hen'

  Hen.lay! {{
    gem: {
      name:         %q{mediawiki-gateway},
      version:      MediaWiki::VERSION,
      summary:      %q{Connect to the MediaWiki API.},
      description:  %q{A Ruby framework for MediaWiki API manipulation.},
      authors:      ['Jani Patokallio', 'Jens Wille'],
      email:        ['jpatokal@iki.fi', 'jens.wille@gmail.com'],
      license:      %q{MIT},
      homepage:     :jpatokal,
      dependencies: { 'rest-client' => '~> 1.7' },

      development_dependencies: %w[
        equivalent-xml
        nokogiri
        sham_rack
        sinatra
      ],

      required_ruby_version: '>= 1.9.3'
    },

    rdoc: {
      extra_files: %w[README.md]
    }
  }}
rescue LoadError => err
  warn "Please install the `hen' gem. (#{err})"
end
