module MediaWiki

  # General exception occurred within MediaWiki::Gateway, and parent class for MediaWiki::APIError, MediaWiki::Unauthorized.
  class Exception < ::StandardError
  end

  # Wrapper for errors returned by MediaWiki API.  Possible codes are defined in http://www.mediawiki.org/wiki/API:Errors_and_warnings.
  #
  # Warnings also throw errors with code 'warning', unless MediaWiki::Gateway#new was called with :ignorewarnings.
  class APIError < Exception

    attr_reader :code, :info, :message

    def initialize(code, info)
      @code, @info, @message = code, info,
        "API error: code '#{code}', info '#{info}'"
    end

    def to_s
      "#{self.class}: #{@message}"
    end

  end

  # User is not authorized to perform this operation.  Also thrown if MediaWiki::Gateway#login fails.
  class Unauthorized < Exception
  end

end
