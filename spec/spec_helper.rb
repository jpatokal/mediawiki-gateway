require 'media_wiki'

require 'rr'
Spec::Runner.configure do |config|
  config.mock_with RR::Adapters::Rspec
end

# :nodoc: Rails 2.3.x: Hash#to_xml is defined in active_support
# :nodoc: Rails 3: #to_xml is defined in ActiveModel::Serializers::Xml
require 'active_support'
unless Hash.method_defined? :to_xml
  require 'active_model'
  Hash.send(:include, ActiveModel::Serializers::Xml)
end
