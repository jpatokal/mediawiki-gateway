# MediaWiki::Gateway

A Ruby framework for MediaWiki API manipulation.  Features out of the box:

* Simple, elegant syntax for common operations
* Handles login, edit, move etc tokens for you
* List, search operations work around API limits to fetch all results
* Support for maxlag detection and automated retries on 503
* Integrated logging
* Tested up to MediaWiki 1.22
* Should work with Ruby 1.9.3 and higher

Gem:  http://rubygems.org/gems/mediawiki-gateway

RDoc: http://rubydoc.info/gems/mediawiki-gateway

Git:  https://github.com/jpatokal/mediawiki-gateway

Travis CI: https://travis-ci.org/jpatokal/mediawiki-gateway

## Example

Simple page creation script:

    require 'media_wiki'
    mw = MediaWiki::Gateway.new('http://my-wiki.example/w/api.php')
    mw.login('RubyBot', 'pa$$w0rd')
    mw.create('PageTitle', 'Hello world!', summary: 'My first page')

## Development environment

To compile and test MediaWiki::Gateway locally, install its development dependencies:

    gem install --development mediawiki-gateway

Then this will list the available options:

    rake -T

To build and install the gem use:

    rake gem:install

### Testing against a live MediaWiki instance

You need to have [Docker](https://docker.com) and [mediawiki-testwiki](https://rubygems.org/gems/mediawiki-testwiki) installed.

## Status

This gem is no longer in active development.  Pull requests that fix bugs or add new features are more than welcome, but asking for new features is unlikely to make them materialize out of thin air.

## Credits

Loosely maintained by Jani Patokallio and [Jens Wille](https://github.com/blackwinter).  If you'd be seriously interested in joining as an active maintainer, drop us a line!

Thanks to:
* John Carney, Mike Williams, Daniel Heath and the rest of the Lonely Planet Atlas team.
* Github users for code contributions, see https://github.com/jpatokal/mediawiki-gateway/pulls
