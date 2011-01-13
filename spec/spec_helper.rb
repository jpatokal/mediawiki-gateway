require 'media_wiki'

require 'rr'
Spec::Runner.configure do |config|
  config.mock_with RR::Adapters::Rspec
end

require 'active_support/version'
if ActiveSupport::VERSION::MAJOR >= 3
  # :nodoc: Rails 3: #to_xml is defined in ActiveModel::Serializers::Xml
  require 'active_model'
  Hash.send(:include, ActiveModel::Serializers::Xml)
else
  # :nodoc: Rails 2.3.x: Hash#to_xml is defined in active_support
  require 'active_support'
end
