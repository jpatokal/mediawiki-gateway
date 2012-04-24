require 'thread' # bizarre workaround for Rails 2.3.x/RubyGems incompatibility
require File.dirname(__FILE__) + '/media_wiki/config'
require File.dirname(__FILE__) + '/media_wiki/exception'
require File.dirname(__FILE__) + '/media_wiki/utils'
require File.dirname(__FILE__) + '/media_wiki/gateway'

module MediaWiki
  VERSION = "0.4.5"
end
