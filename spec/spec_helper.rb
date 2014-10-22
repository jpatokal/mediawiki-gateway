require 'media_wiki'

require 'nokogiri'
require 'equivalent-xml/rspec_matchers'

RSpec.configure { |config|
  %w[expect mock].each { |what|
    config.send("#{what}_with", :rspec) { |c| c.syntax = [:should, :expect] }
  }

  config.include(Module.new {
    def data(file)
      File.join(File.dirname(__FILE__), 'data', file)
    end
  })

  config.alias_example_group_to :describe_fake, begin
    require 'media_wiki/fake_wiki'

    { fake: true }.tap { |filter|
      MediaWiki::FakeWiki::RSpecAdapter.enhance(config, filter) }
  end

  config.alias_example_group_to :describe_live, begin
    require 'media_wiki/test_wiki/rspec_adapter'
  rescue LoadError
    { skip: 'MediaWiki::TestWiki not available'.tap { |msg|
      warn "#{msg}. Install the `mediawiki-testwiki' gem." } }
  else
    { live: true }.tap { |filter|
      MediaWiki::TestWiki::RSpecAdapter.enhance(config, filter) }
  end
}
