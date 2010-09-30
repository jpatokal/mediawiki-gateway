require 'rubygems'
require 'logger'
require 'rest_client'
require 'rexml/document'
require 'uri'
require 'lib/media_wiki/utils'

module MediaWiki

  class Gateway

    # Set up a MediaWiki::Gateway for a given MediaWiki installation
    #
    # [url] Path to API of target MediaWiki (eg. "http://en.wikipedia.org/w/api.php")
    # [loglevel] Log level to use (optional, defaults to Logger::WARN)
    def initialize(url, loglevel = Logger::WARN)
      @log = Logger.new(STDERR)
      @log.level = loglevel
      @wiki_url = url
      @headers = { "User-Agent" => "MediaWiki::Gateway/#{MediaWiki.version}" }
      @cookies = {}
    end
    
    attr_reader :base_url
    
    # Login to MediaWiki
    #
    # [username] Username
    # [password] Password
    # [domain] Domain for authentication plugin logins (eg. LDAP), optional -- defaults to 'local' if not given
    #
    # Throws error if login fails
    def login(username, password, domain = 'local')
      form_data = {'action' => 'login', 'lgname' => username, 'lgpassword' => password, 'lgdomain' => domain}
      make_api_request(form_data)
      @password = password
      @username = username
    end
    
    # Fetch MediaWiki page in MediaWiki format
    #
    # [page_title] Page title to fetch
    #
    # Returns nil if the page does not exist
    def get(page_title)
      form_data = {'action' => 'query', 'prop' => 'revisions', 'rvprop' => 'content', 'titles' => page_title}
      page = make_api_request(form_data).elements["query/pages/page"]
      if ! page or page.attributes["missing"]
        nil
      else
        page.elements["revisions/rev"].text
      end
    end

    # Render a MediaWiki page as HTML
    #
    # [page_title] Page title to fetch
    #
    # Returns nil if the page does not exist
    def render(page_title)
      form_data = {'action' => 'parse', 'page' => page_title}
      parsed = make_api_request(form_data).elements["parse"]
      if parsed.attributes["revid"] != '0'
        return parsed.elements["text"].text.gsub(/<!--(.|\s)*?-->/, '')
      else
        nil
      end
    end
        
    # Create a new page, or overwrite an existing one
    #
    # [title] Page title to create or overwrite, string
    # [content] Content for the page, string
    # [options] Hash of additional options
    #
    # Options:
    # * [overwrite] Allow overwriting existing pages
    # * [summary] Edit summary for history, string
    # * [token] Use this existing edit token instead requesting a new one (useful for bulk loads)
    def create(title, content, options={})
      form_data = {'action' => 'edit', 'title' => title, 'text' => content, 'summary' => (options[:summary] || ""), 'token' => get_token('edit', title)}
      form_data['createonly'] = "" unless options[:overwrite]
      make_api_request(form_data)
    end
    
    # Delete one page. (MediaWiki API does not support deleting multiple pages at a time.)
    #
    # [title] Title of page to delete
    def delete(title)
      form_data = {'action' => 'delete', 'title' => title, 'token' => get_token('delete', title)}
      make_api_request(form_data)
    end

    # Undelete all revisions of one page.
    #
    # [title] Title of page to undelete
    #
    # Returns number of revisions undeleted.
    def undelete(title)
      token = get_undelete_token(title)
      if token
        form_data = {'action' => 'undelete', 'title' => title, 'token' => token }
        xml = make_api_request(form_data)
        xml.elements["undelete"].attributes["revisions"].to_i
      else
        0 # No revisions to undelete
      end
    end

    # Get a list of matching page titles
    #
    # [key] Search key, matched as a prefix (^key.*).  May contain or equal a namespace.
    #
    # Returns array of page titles (empty if no matches)
    def list(key)
      titles = []
      apfrom = nil
      key, namespace = key.split(":", 2).reverse
      namespace = namespaces_by_prefix[namespace] || 0
      begin
        form_data =
          {'action' => 'query',
          'list' => 'allpages',
          'apfrom' => apfrom,
          'apprefix' => key,
          'aplimit' => 500, # max allowed by API
          'apnamespace' => namespace}
        res = make_api_request(form_data)
        apfrom = res.elements['query-continue'] ? res.elements['query-continue/allpages'].attributes['apfrom'] : nil
        titles += REXML::XPath.match(res, "//p").map { |x| x.attributes["title"] }
      end while apfrom
      titles
    end

    # Get a list of pages with matching content in given namespaces
    #
    # [key] Search key
    # [namespaces] Array of namespace names to search (defaults to NS_MAIN only)
    # [limit] Max number of hits to return
    #
    # Returns array of page titles (empty if no matches)
    def search(key, namespaces=nil, limit=10)
      titles = []
      form_data = { 'action' => 'query',
        'list' => 'search',
        'srwhat' => 'text',
        'srsearch' => key,
        'srlimit' => limit}
      if namespaces
        namespaces = [ namespaces ] unless namespaces.kind_of? Array
        form_data['srnamespace'] = namespaces.map! do |ns| namespaces_by_prefix[ns] end.join('|')
      end
      titles += REXML::XPath.match(make_api_request(form_data), "//p").map { |x| x.attributes["title"] }
    end

    # Upload file to MediaWiki
    # Requires Mediawiki 1.16+
    #
    # [path] Path to file to upload
    # [options] Hash of additional options
    #
    # Options:
    # * [description] Description of this file
    # * [target] Target filename, defaults to local name if not given
    # * [summary] Edit summary for history
    def upload(path, options={})
      comment = (options[:summary] || "Uploaded by MediaWiki::Gateway")
      file = File.new(path)
      filename = (options[:target] || File.basename(path))
      form_data = { 'action' => 'upload',
        'filename' => filename,
        'file' => file,
        'token'   => get_token('edit', filename),
        'text' => (options[:description] || options[:summary]),
        'comment' => comment}
      make_api_request(form_data)
    end

    # Imports a MediaWiki XML dump
    #
    # [xml] String or array of page names to fetch
    #
    # Returns XML array <api><import><page/><page/>... 
    # <page revisions="1"> (or more) means successfully imported
    # <page revisions="0"> means duplicate, not imported
    def import(xmlfile)
      form_data = { "action"  => "import",
        "xml"     => File.new(xmlfile),
        "token"   => get_token('import', 'Main Page'), # NB: dummy page name
        "format"  => 'xml' }
      make_api_request(form_data)
    end

    # Exports a page or set of pages
    #
    # [page_titles] String or array of page titles to fetch
    #
    # Returns MediaWiki XML dump
    def export(page_titles)
      form_data = {'action' => 'query', 'titles' => [page_titles].join('|'), 'export' => nil, 'exportnowrap' => nil}
      return make_api_request(form_data)
    end

    # Get a list of all known namespaces
    #
    # Returns array of namespaces (name => id)
    def namespaces_by_prefix
      form_data = { 'action' => 'query', 'meta' => 'siteinfo', 'siprop' => 'namespaces' }
      res = make_api_request(form_data)
      REXML::XPath.match(res, "//ns").inject(Hash.new) do |namespaces, namespace|
        prefix = namespace.attributes["canonical"] || ""
        namespaces[prefix] = namespace.attributes["id"].to_i
        namespaces
      end
    end

    # Get a list of all installed (and registered) extensions
    #
    # Returns array of extensions (name => version)
    def extensions
      form_data = { 'action' => 'query', 'meta' => 'siteinfo', 'siprop' => 'extensions' }
      res = make_api_request(form_data)
      REXML::XPath.match(res, "//ext").inject(Hash.new) do |extensions, extension|
        name = extension.attributes["name"] || ""
        extensions[name] = extension.attributes["version"]
        extensions
      end
    end
    
    # Execute Semantic Mediawiki query
    #
    # [query] Semantic Mediawiki query
    # [params] Array of additional parameters or options, eg. mainlabel=Foo or ?Place (optional)
    #
    # Returns result as an HTML string
    def semantic_query(query, params = [])
      params << "format=list"
      form_data = { 'action' => 'parse', 'prop' => 'text', 'text' => "{{#ask:#{query}|#{params.join('|')}}}" }
      xml = make_api_request(form_data)
      return xml.elements["parse/text"].text
    end

    private

    # Fetch token (type 'delete', 'edit', 'import')
    def get_token(type, page_titles)
      form_data = {'action' => 'query', 'prop' => 'info', 'intoken' => type, 'titles' => page_titles}
      res = make_api_request(form_data)
      token = res.elements["query/pages/page"].attributes[type + "token"]
      raise "User is not permitted to perform this operation: #{type}" if token.nil?
      token
    end

    def get_undelete_token(page_titles)
      form_data = {'action' => 'query', 'list' => 'deletedrevs', 'prop' => 'info', 'drprop' => 'token', 'titles' => page_titles}
      res = make_api_request(form_data)
      if res.elements["query/deletedrevs/page"]
        token = res.elements["query/deletedrevs/page"].attributes["token"]
        raise "User is not permitted to perform this operation: #{type}" if token.nil?
        token
      else
        nil
      end
    end

    # Make generic request to API
    #
    # [form_data] hash or string of attributes to post
    #
    # Returns XML document
    def make_api_request(form_data)
      form_data['format'] = 'xml' if form_data.kind_of? Hash
      @log.debug("REQ: #{form_data.inspect}, #{@cookies.inspect}")
      RestClient.post(@wiki_url, form_data, @headers.merge({:cookies => @cookies})) do |response, &block| 
        # Check response for errors and return XML
        raise "API error, bad response: #{response}" unless response.code >= 200 and response.code < 300 
        doc = get_response(response.dup)
        if(form_data['action'] == 'login')
          login_result = doc.elements["login"].attributes['result']
          @cookies.merge!(response.cookies)
          case login_result
            when "Success" then # do nothing
            when "NeedToken" then make_api_request(form_data.merge('lgtoken' => doc.elements["login"].attributes["token"]))
            else raise "Login failed: " + login_result
          end
        end
        return doc
      end

    end
    
    # Get API XML response
    # If there are errors, print and bail out
    # Otherwise return XML root
    def get_response(res)
      doc = REXML::Document.new(res).root
      @log.debug("RES: #{doc}")
      raise "API error, response does not contain Mediawiki API XML: #{res}" unless [ "api", "mediawiki" ].include? doc.name
      if doc.elements["error"]
        code = doc.elements["error"].attributes["code"]
        info = doc.elements["error"].attributes["info"]
        raise "API error: code '#{code}', info '#{info}'"
      end
      doc
    end

  end
end
