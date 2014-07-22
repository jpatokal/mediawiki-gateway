begin
  require 'simplecov'
  SimpleCov.start
rescue LoadError
  warn 'SimpleCov not available. Install it with: gem install simplecov'
end

require 'media_wiki'

RSpec.configure { |config|
  %w[expect mock].each { |what|
    config.send("#{what}_with", :rspec) { |c| c.syntax = [:should, :expect] }
  }
}

# :nodoc: Rails 2.3.x: Hash#to_xml is defined in active_support
# :nodoc: Rails 3: #to_xml is defined in ActiveModel::Serializers::Xml
require 'active_support'
unless Hash.method_defined? :to_xml
  require 'active_model'
  Hash.send(:include, ActiveModel::Serializers::Xml)
end
