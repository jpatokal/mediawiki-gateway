require 'delegate'
require 'rexml/document'

module MediaWiki

  class Response < ::SimpleDelegator
    attr_reader :doc

    def initialize(response)
      super(response)

      self.force_encoding('UTF-8') if self.respond_to?(:force_encoding)

      begin
        @doc = REXML::Document.new(response).root
      rescue REXML::ParseException
        raise MediaWiki::Exception.new('Response is not XML.  Are you sure you are pointing to api.php?')
      end
    end

    def has_error?
      ! self.error.nil?
    end

    def error
      @doc.elements['error']
    end

    def error_code
      self.error.attributes['code']
    end

    def error_info
      self.error.attributes['info']
    end

    def has_warnings?
      ! self.warnings.nil?
    end

    def warnings
      @doc.elements['warnings']
    end
  end

end
