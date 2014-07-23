# MediaWiki::Gateway

A Ruby framework for MediaWiki API manipulation.  Features out of the box:

* Simple, elegant syntax for common operations
* Handles login, edit, move etc tokens for you
* List, search operations work around API limits to fetch all results
* Support for maxlag detection and automated retries on 503
* Integrated logging
* Tested up to MediaWiki 1.22
* Should work with both Ruby 1.8 and 1.9

Gem:  http://rubygems.org/gems/mediawiki-gateway
RDoc: http://rubydoc.info/gems/mediawiki-gateway
Git:  https://github.com/jpatokal/mediawiki-gateway

## Example

Simple page creation script:

 require 'media_wiki'
 mw = MediaWiki::Gateway.new('http://my-wiki.example/w/api.php')
 mw.login('RubyBot', 'pa$$w0rd')
 mw.create('PageTitle', 'Hello world!', :summary => 'My first page')

## Development environment

To compile and test MediaWiki::Gateway locally, Bundler and Ruby 1.9+ are expected.

 rvm install 1.9.3-p194
 bundle install

This will list the available options:
 bundle exec rake -T

To build and install the gem use:
 bundle exec rake install

## Status

This gem is no longer in active development.  Bugs will be fixed if reported, and pull requests that add new features are more than welcome, but asking for new features is unlikely to make them materialize out of thin air.

## Credits

Maintained by Jani Patokallio.

Thanks to:
* John Carney, Mike Williams, Daniel Heath and the rest of the Lonely Planet Atlas team.
* Github users for code contributions, see https://github.com/jpatokal/mediawiki-gateway/pulls

