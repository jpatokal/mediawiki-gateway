# MediaWiki::Gateway

A Ruby framework for [MediaWiki API](http://www.mediawiki.org/wiki/API:Main_page) manipulation.

## Features

* Simple, elegant syntax for common operations
* Handles login, edit, move etc. tokens for you
* List, search operations work around API limits to fetch all results
* Support for maxlag detection and automated retries on 503
* Integrated logging
* Tested up to MediaWiki 1.22
* Should work with Ruby 1.9.3 and higher

## Links

RubyGem
: http://rubygems.org/gems/mediawiki-gateway

Documentation
: http://rubydoc.info/gems/mediawiki-gateway

Source
: https://github.com/jpatokal/mediawiki-gateway

CI
: https://travis-ci.org/jpatokal/mediawiki-gateway

## Installation

To install MediaWiki::Gateway, execute the command:

```shell
$ gem install mediawiki-gateway
```

Or add it to your application's `Gemfile`:

```ruby
gem 'mediawiki-gateway'
```

and then execute the command:

```shell
$ bundle
```

## Usage

Simple page creation script:

```ruby
require 'media_wiki'
mw = MediaWiki::Gateway.new('http://my-wiki.example/w/api.php')
mw.login('RubyBot', 'pa$$w0rd')
mw.create('PageTitle', 'Hello world!', summary: 'My first page')
```

## Changing the default User-Agent

In order to comply with Wikimedia's [User-Agent policy](https://meta.wikimedia.org/wiki/User-Agent_policy), you are strongly advised to provide your own User-Agent header when accessing Wikimedia websites. The User-Agent information should include the name and version of your bot as well as a URL (homepage, repository) and contact e-mail.

You can set the default User-Agent globally:

```ruby
MediaWiki::Gateway.default_user_agent = 'MyCoolTool/1.1 (http://example.com/MyCoolTool/; MyCoolTool@example.com)'
```

You can also set it on an instance by instance basis, overriding the global default:

```ruby
mw = MediaWiki::Gateway.new('http://my-wiki.example/w/api.php', user_agent: 'MyCoolTool/1.1 (http://example.com/MyCoolTool/; MyCoolTool@example.com)')
```

You only need to provide the part that identifies your own bot, an additional part denoting that your bot is based on MediaWiki::Gateway is appended automatically.

## Development environment

To compile and test MediaWiki::Gateway locally, install its development dependencies:

```shell
gem install --development mediawiki-gateway
```

Then this will list the available options:

```shell
rake -T
```

To build and install the gem use:

```shell
rake gem:install
```

### Testing against a live MediaWiki instance

You need to have [Docker](https://docker.com) and [mediawiki-testwiki](https://rubygems.org/gems/mediawiki-testwiki) installed.

## Status

This gem is no longer in active development. Pull requests that fix bugs or add new features are more than welcome, but asking for new features is unlikely to make them materialize out of thin air.

## Credits

Loosely maintained by Jani Patokallio and [Jens Wille](https://github.com/blackwinter). If you'd be seriously interested in joining as an active maintainer, drop us a line!

Thanks to:

* John Carney, Mike Williams, Daniel Heath and the rest of the Lonely Planet Atlas team.
* GitHub users for code contributions, see https://github.com/jpatokal/mediawiki-gateway/pulls
