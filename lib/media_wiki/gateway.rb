require 'logger'
require 'rest_client'
require 'rexml/document'
require 'uri'

module MediaWiki

  class Gateway

    USER_AGENT = "#{self}/#{VERSION}"

    class << self

      attr_accessor :default_user_agent

    end

    # Set up a MediaWiki::Gateway for a given MediaWiki installation
    #
    # [url] Path to API of target MediaWiki (eg. 'http://en.wikipedia.org/w/api.php')
    # [options] Hash of options
    # [http_options] Hash of options for RestClient::Request (via http_send)
    #
    # Options:
    # [:bot] When set to true, executes API queries with the bot parameter (see http://www.mediawiki.org/wiki/API:Edit#Parameters).  Defaults to false.
    # [:ignorewarnings] Log API warnings and invalid page titles, instead throwing MediaWiki::APIError
    # [:limit] Maximum number of results returned per search (see http://www.mediawiki.org/wiki/API:Query_-_Lists#Limits), defaults to the MediaWiki default of 500.
    # [:logdevice] Log device to use.  Defaults to STDERR
    # [:loglevel] Log level to use, defaults to Logger::WARN.  Set to Logger::DEBUG to dump every request and response to the log.
    # [:maxlag] Maximum allowed server lag (see http://www.mediawiki.org/wiki/Manual:Maxlag_parameter), defaults to 5 seconds.
    # [:retry_count] Number of times to try before giving up if MediaWiki returns 503 Service Unavailable, defaults to 3 (original request plus two retries).
    # [:retry_delay] Seconds to wait before retry if MediaWiki returns 503 Service Unavailable, defaults to 10 seconds.
    # [:user_agent] User-Agent header to send with requests, defaults to ::default_user_agent or nil.
    def initialize(url, options = {}, http_options = {})
      @options = {
        bot:         false,
        limit:       500,
        logdevice:   STDERR,
        loglevel:    Logger::WARN,
        max_results: 500,
        maxlag:      5,
        retry_count: 3,
        retry_delay: 10,
        user_agent:  self.class.default_user_agent
      }.merge(options)

      @log = Logger.new(@options[:logdevice])
      @log.level = @options[:loglevel]

      @http_options, @wiki_url, @cookies, @headers = http_options, url, {}, {
        'User-Agent'      => [@options[:user_agent], USER_AGENT].compact.join(' '),
        'Accept-Encoding' => 'gzip'
      }
    end

    attr_reader :log, :wiki_url, :cookies, :headers

    # Make generic request to API
    #
    # [form_data] hash of attributes to post
    # [continue_xpath] XPath selector for query continue parameter
    #
    # Returns XML document
    def send_request(form_data, continue_xpath = nil)
      make_api_request(form_data, continue_xpath).first
    end

    private

    # Fetch token (type 'delete', 'edit', 'email', 'import', 'move', 'protect')
    def get_token(type, page_titles)
      res = send_request(
        'action'  => 'query',
        'meta'    => 'tokens'
      )

      unless token = res.elements['query/tokens'].attributes["csrftoken"]
        raise Unauthorized.new "User is not permitted to perform this operation: #{type}"
      end

      token
    end

    # Iterate over query results
    #
    # [list] list name to query
    # [res_xpath] XPath selector for results
    # [attr] attribute name to extract, if any
    # [param] parameter name to continue query
    # [options] additional query options
    #
    # Yields each attribute value, or, if +attr+ is nil, each REXML::Element.
    def iterate_query(list, res_xpath, attr, param, options, &block)
      items, block = [], lambda { |item| items << item } unless block

      attribute_names = %w[from continue].map { |name|
        "name()='#{param[0, 2]}#{name}'"
      }

      req_xpath = "//query-continue/#{list}/@*[#{attribute_names.join(' or ')}]"
      res_xpath = "//query/#{list}/#{res_xpath}" unless res_xpath.start_with?('/')

      options, continue = options.merge('action' => 'query', 'list' => list), nil

      loop {
        res, continue = make_api_request(options, req_xpath)

        REXML::XPath.match(res, res_xpath).each { |element|
          block[attr ? element.attributes[attr] : element]
        }

        continue ? options[param] = continue : break
      }

      items
    end

    # Make generic request to API
    #
    # [form_data] hash of attributes to post
    # [continue_xpath] XPath selector for query continue parameter
    # [retry_count] Counter for retries
    #
    # Returns array of XML document and query continue parameter.
    def make_api_request(form_data, continue_xpath = nil, retry_count = 1)
      form_data.update('format' => 'xml', 'maxlag' => @options[:maxlag])

      http_send(@wiki_url, form_data, @headers.merge(cookies: @cookies)) do |response|
        if response.code == 503 && retry_count < @options[:retry_count]
          log.warn("503 Service Unavailable: #{response.body}.  Retry in #{@options[:retry_delay]} seconds.")
          sleep(@options[:retry_delay])
          make_api_request(form_data, continue_xpath, retry_count + 1)
        end

        # Check response for errors and return XML
        unless response.code >= 200 && response.code < 300
          raise MediaWiki::Exception.new("Bad response: #{response}")
        end

        doc = get_response(response.dup)

        # login and createaccount actions require a second request with a token received on the first request
        if %w[login createaccount].include?(action = form_data['action'])
          action_result = doc.elements[action].attributes['result']
          @cookies.update(response.cookies)

          case action_result.downcase
            when 'success'
              return [doc, false]
            when 'needtoken'
              token = doc.elements[action].attributes['token']

              if action == 'login'
                return make_api_request(form_data.merge('lgtoken' => token))
              elsif action == 'createaccount'
                return make_api_request(form_data.merge('token' => token))
              end
            else
              if action == 'login'
                raise Unauthorized.new("Login failed: #{action_result}")
              elsif action == 'createaccount'
                raise Unauthorized.new("Account creation failed: #{action_result}")
              end
          end
        end

        return [doc, (continue_xpath && doc.elements['query-continue']) ?
          REXML::XPath.first(doc, continue_xpath) : nil]
      end
    end

    # Execute the HTTP request using either GET or POST as appropriate.
    # @yieldparam response
    def http_send url, form_data, headers, &block
      opts = @http_options.merge(url: url, headers: headers, verify_ssl: false)
      opts[:method] = form_data['action'] == 'query' ? :get : :post
      opts[:method] == :get ? headers[:params] = form_data : opts[:payload] = form_data

      log.debug("#{opts[:method].upcase}: #{form_data.inspect}, #{@cookies.inspect}")

      RestClient::Request.execute(opts) do |response, request, result|
        # When a block is passed to RestClient::Request.execute, we must
        # manually handle response codes ourselves. If no block is passed,
        # then redirects are automatically handled, but HTTP errors also
        # result in exceptions being raised. For now, we manually check for
        # HTTP 503 errors (see: #make_api_request), but we must also manually
        # handle HTTP redirects.
        if [301, 302, 307].include?(response.code) && request.method == :get
          response = response.follow_redirection(request, result)
        end

        block.call(response)
      end

    end

    # Get API XML response
    # If there are errors or warnings, raise APIError
    # Otherwise return XML root
    def get_response(res)
      begin
        res = res.force_encoding('UTF-8') if res.respond_to?(:force_encoding)
        doc = REXML::Document.new(res).root
      rescue REXML::ParseException
        raise MediaWiki::Exception.new('Response is not XML.  Are you sure you are pointing to api.php?')
      end

      log.debug("RES: #{doc}")

      unless %w[api mediawiki].include?(doc.name)
        raise MediaWiki::Exception.new("Response does not contain Mediawiki API XML: #{res}")
      end

      if error = doc.elements['error']
        raise APIError.new(*error.attributes.values_at(*%w[code info]))
      end

      if warnings = doc.elements['warnings']
        warning("API warning: #{warnings.children.map(&:text).join(', ')}")
      end

      doc
    end

    def validate_options(options, valid_options)
      options.each_key { |opt|
        unless valid_options.include?(opt.to_s)
          raise ArgumentError, "Unknown option '#{opt}'", caller(1)
        end
      }
    end

    def valid_page?(page)
      page && !page.attributes['missing'] && (!page.attributes['invalid'] ||
        warning("Invalid title '#{page.attributes['title']}'"))
    end

    def warning(msg)
      raise APIError.new('warning', msg) unless @options[:ignorewarnings]
      log.warn(msg)
      false
    end

  end

end

require_relative 'gateway/files'
require_relative 'gateway/pages'
require_relative 'gateway/query'
require_relative 'gateway/site'
require_relative 'gateway/users'
