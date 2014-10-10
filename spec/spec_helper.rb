require 'media_wiki'

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

# :nodoc: Rails 2.3.x: Hash#to_xml is defined in active_support
# :nodoc: Rails 3: #to_xml is defined in ActiveModel::Serializers::Xml
require 'active_support'
unless Hash.method_defined? :to_xml
  require 'active_model'
  Hash.send(:include, ActiveModel::Serializers::Xml)
end
