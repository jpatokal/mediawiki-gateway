require 'rubygems'
require 'logger'
require 'rest_client'
require 'rexml/document'
require 'uri'

module MediaWiki

  class Gateway
    API_MAX_LIMIT = 500

    # Set up a MediaWiki::Gateway for a given MediaWiki installation
    #
    # [url] Path to API of target MediaWiki (eg. "http://en.wikipedia.org/w/api.php")
    # [loglevel] Log level to use (optional, defaults to Logger::WARN)
    def initialize(url, loglevel = Logger::WARN)
      @log = Logger.new(STDERR)
      @log.level = loglevel
      @wiki_url = url
      @headers = { "User-Agent" => "MediaWiki::Gateway/#{MediaWiki::VERSION}" }
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
    # Returns content of page as string, nil if the page does not exist
    def get(page_title)
      form_data = {'action' => 'query', 'prop' => 'revisions', 'rvprop' => 'content', 'titles' => page_title}
      page = make_api_request(form_data).elements["query/pages/page"]
      if ! page or page.attributes["missing"]
        nil
      else
        page.elements["revisions/rev"].text || ""
      end
    end

    # Render a MediaWiki page as HTML
    #
    # [page_title] Page title to fetch
    # [options] Hash of additional options
    #
    # Options:
    # * [linkbase] supply a String to prefix all internal (relative) links with. '/wiki/' is assumed to be the base of a relative link
    # * [noeditsections] strips all edit-links if set to +true+
    # * [noimages] strips all +img+ tags from the rendered text if set to +true+
    # 
    # Returns rendered page as string, or nil if the page does not exist
    def render(page_title, options = {})
      form_data = {'action' => 'parse', 'page' => page_title}

      valid_options = %w(linkbase noeditsections noimages)
      # Check options
      options.keys.each{|opt| raise ArgumentError.new("Unknown option '#{opt}'") unless valid_options.include?(opt.to_s)}

      rendered = nil
      parsed = make_api_request(form_data).elements["parse"]
      if parsed.attributes["revid"] != '0'
        rendered = parsed.elements["text"].text.gsub(/<!--(.|\s)*?-->/, '')
        # OPTIMIZE: unifiy the keys in +options+ like symbolize_keys! but w/o
        if options["linkbase"] or options[:linkbase]
          linkbase = options["linkbase"] || options[:linkbase]
          rendered = rendered.gsub(/\shref="\/wiki\/([\w\(\)_\-\.%\d:,]*)"/, ' href="' + linkbase + '/wiki/\1"')
        end
        if options["noeditsections"] or options[:noeditsections]
          rendered = rendered.gsub(/<span class="editsection">\[.+\]<\/span>/, '')
        end
        if options["noimages"] or options[:noimages]
          rendered = rendered.gsub(/<img.*\/>/, '')
        end
      end
      rendered
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
    
    # Move a page to a new title
    #
    # [from] Old page name
    # [to] New page name
    # [options] Hash of additional options
    #
    # Options:
    # * [movesubpages] Move associated subpages
    # * [movetalk] Move associated talkpages
    # * [noredirect] Do not create a redirect page from old name.  Requires the 'suppressredirect' user right, otherwise MW will silently ignore the option and create the redirect anyway.
    # * [reason] Reason for move
    # * [watch] Add page and any redirect to watchlist
    # * [unwatch] Remove page and any redirect from watchlist
    def move(from, to, options={})
      valid_options = %w(movesubpages movetalk noredirect reason watch unwatch)
      options.keys.each{|opt| raise ArgumentError.new("Unknown option '#{opt}'") unless valid_options.include?(opt.to_s)}
      
      form_data = options.merge({'action' => 'move', 'from' => from, 'to' => to, 'token' => get_token('move', from)})
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
    # Returns number of revisions undeleted, or zero if nothing to undelete
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

    # Get a list of matching page titles in a namespace
    #
    # [key] Search key, matched as a prefix (^key.*).  May contain or equal a namespace, defaults to main (namespace 0) if none given.
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
          'aplimit' => API_MAX_LIMIT,
          'apnamespace' => namespace}
        res = make_api_request(form_data)
        apfrom = res.elements['query-continue'] ? res.elements['query-continue/allpages'].attributes['apfrom'] : nil
        titles += REXML::XPath.match(res, "//p").map { |x| x.attributes["title"] }
      end while apfrom
      titles
    end

    # Get a list of pages that link to a target page
    #
    # [title] Link target page
    # [filter] "all" links (default), "redirects" only, or "nonredirects" (plain links only)
    #
    # Returns array of page titles (empty if no matches)
    def backlinks(title, filter = "all")
      titles = []
      blcontinue = nil
      begin
        form_data =
          {'action' => 'query',
          'list' => 'backlinks',
          'bltitle' => title,
          'blfilterredir' => filter,
          'bllimit' => API_MAX_LIMIT }
        form_data['blcontinue'] = blcontinue if blcontinue
        res = make_api_request(form_data)
        blcontinue = res.elements['query-continue'] ? res.elements['query-continue/backlinks'].attributes['blcontinue'] : nil
        titles += REXML::XPath.match(res, "//bl").map { |x| x.attributes["title"] }
      end while blcontinue
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

    # Upload a file, or get the status of pending uploads. Several 
    # methods are available:
    #
    # * Upload file contents directly.
    # * Have the MediaWiki server fetch a file from a URL, using the 
    #   "url" parameter
    #
    # Requires Mediawiki 1.16+
    #
    # Arguments:
    # * [path] Path to file to upload. Set to nil if uploading from URL.
    # * [options] Hash of additional options
    # 
    # Note that queries using session keys must be done in the same login 
    # session as the query that originally returned the key (i.e. do not
    # log out and then log back in).
    #
    # Options:
    # * 'filename'       - Target filename (defaults to local name if not given), options[:target] is alias for this.
    # * 'comment'        - Upload comment. Also used as the initial page text for new files if "text" is not specified.
    # * 'text'           - Initial page text for new files
    # * 'watch'          - Watch the page
    # * 'ignorewarnings' - Ignore any warnings
    # * 'url'            - Url to fetch the file from. Set path to nil if you want to use this.
    #
    # Deprecated but still supported options:
    # * :description     - Description of this file. Used as 'text'.
    # * :target          - Target filename, same as 'filename'.
    # * :summary         - Edit summary for history. Used as 'comment'. Also used as 'text' if neither it or :description is specified.
    # 
    # Examples:
    #   mw.upload('/path/to/local/file.jpg', 'filename' => "RemoteFile.jpg")
    #   mw.upload(nil, 'filename' => "RemoteFile2.jpg", 'url' => 'http://remote.com/server/file.jpg')
    #
    def upload(path, options={})
      if options[:description]
        options['text'] = options[:description]
        options.delete(:description)
      end

      if options[:target]
        options['filename'] = options[:target]
        options.delete(:target)
      end

      if options[:summary]
        options['text'] ||= options[:summary]
        options['comment'] = options[:summary]
        options.delete(:summary)
      end

      options['comment'] ||= "Uploaded by MediaWiki::Gateway"
      options['file'] = File.new(path) if path
      full_name = path || options['url']
      options['filename'] ||= File.basename(full_name) if full_name

      raise ArgumentError.new(
        "One of the 'file', 'url' or 'sessionkey' options must be specified!"
      ) unless options['file'] || options['url'] || options['sessionkey']

      form_data = options.merge(
        'action' => 'upload',
        'token' => get_token('edit', options['filename'])
      )

      make_api_request(form_data)
    end
    
    # Requests image info from MediaWiki. Follows redirects.
    #
    # _file_name_or_page_id_ should be either:
    # * a file name (String) you want info about without File: prefix.
    # * or a Fixnum page id you of the file.
    #
    # _options_ is +Hash+ passed as query arguments. See
    # http://www.mediawiki.org/wiki/API:Query_-_Properties#imageinfo_.2F_ii
    # for more information.
    #
    # options['iiprop'] should be either a string of properties joined by
    # '|' or an +Array+ (or more precisely something that responds to #join).
    #
    # +Hash+ like object is returned where keys are image properties.
    #
    # Example:
    #   mw.image_info(
    #     "Trooper.jpg", 'iiprop' => ['timestamp', 'user']
    #   ).each do |key, value|
    #     puts "#{key.inspect} => #{value.inspect}"
    #   end
    #
    # Output:
    #   "timestamp" => "2009-10-31T12:59:11Z"
    #   "user" => "Valdas"
    #
    def image_info(file_name_or_page_id, options={})
      options['iiprop'] = options['iiprop'].join('|') \
        if options['iiprop'].respond_to?(:join)
      form_data = options.merge(
        'action' => 'query',
        'prop' => 'imageinfo',
        'redirects' => true
      )

      case file_name_or_page_id
      when Fixnum
        form_data['pageids'] = file_name_or_page_id
      else
        form_data['titles'] = "File:#{file_name_or_page_id}"
      end

      xml = make_api_request(form_data)
      page = xml.elements["query/pages/page"]
      if ! page or page.attributes["missing"]
        nil
      elsif xml.elements["query/redirects/r"]
        # We're dealing with redirect here.
        image_info(page.attributes["pageid"].to_i, options)
      else
        page.elements["imageinfo/ii"].attributes
      end
    end

    # Download _file_name_. Returns file contents. All options are passed to 
    # #image_info however options['iiprop'] is forced to url. You can still
    # set other options to control what file you want to download.
    def download(file_name, options={})
      options['iiprop'] = 'url'
  
      attributes = image_info(file_name, options)
      if attributes
        RestClient.get attributes['url']
      else
        nil
      end
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

    # Fetch token (type 'delete', 'edit', 'import', 'move')
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
    # If there are errors, raise exception
    # Otherwise return XML root
    def get_response(res)
      begin
        doc = REXML::Document.new(res).root
      rescue REXML::ParseException => e
        raise "Response is not XML.  Are you sure you are pointing to api.php?"
      end
      @log.debug("RES: #{doc}")
      raise "Response does not contain Mediawiki API XML: #{res}" unless [ "api", "mediawiki" ].include? doc.name
      if doc.elements["error"]
        code = doc.elements["error"].attributes["code"]
        info = doc.elements["error"].attributes["info"]
        raise "API error: code '#{code}', info '#{info}'"
      end
      doc
    end
  end
end
