require 'media_wiki'

require 'nokogiri'
require 'equivalent-xml/rspec_matchers'

require_relative 'fake_media_wiki/app'

RSpec.configure { |config|
  %w[expect mock].each { |what|
    config.send("#{what}_with", :rspec) { |c| c.syntax = [:should, :expect] }
  }

  config.alias_example_group_to :describe_live, begin
    require 'media_wiki/test_wiki/rspec_adapter'
  rescue LoadError
    { skip: 'MediaWiki::TestWiki not available'.tap { |msg|
      warn "#{msg}. Install it with: gem install mediawiki-testwiki" } }
  else
    { live: true }.tap { |filter|
      MediaWiki::TestWiki::RSpecAdapter.enhance(config, filter) }
  end
}
