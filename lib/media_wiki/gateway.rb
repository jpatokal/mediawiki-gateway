require 'logger'
require 'rest_client'
require 'rexml/document'
require 'uri'
require 'active_support'

module MediaWiki

  class Gateway

    attr_reader :log

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
    def initialize(url, options = {}, http_options = {})
      @options = {
        bot:         false,
        limit:       500,
        logdevice:   STDERR,
        loglevel:    Logger::WARN,
        max_results: 500,
        maxlag:      5,
        retry_count: 3,
        retry_delay: 10
      }.merge(options)

      @log = Logger.new(@options[:logdevice])
      @log.level = @options[:loglevel]

      @http_options, @wiki_url, @cookies, @headers = http_options, url, {}, {
        'User-Agent'      => "#{self.class}/#{MediaWiki::VERSION}",
        'Accept-Encoding' => 'gzip'
      }
    end

    attr_reader :base_url, :cookies

    # Login to MediaWiki
    #
    # [username] Username
    # [password] Password
    # [domain] Domain for authentication plugin logins (eg. LDAP), optional -- defaults to 'local' if not given
    # [options] Hash of additional options
    #
    # Throws MediaWiki::Unauthorized if login fails
    def login(username, password, domain = 'local', options = {})
      make_api_request(options.merge(
        'action'     => 'login',
        'lgname'     => username,
        'lgpassword' => password,
        'lgdomain'   => domain
      ))

      @password = password
      @username = username
    end

    # Fetch MediaWiki page in MediaWiki format.  Does not follow redirects.
    #
    # [page_title] Page title to fetch
    # [options] Hash of additional options
    #
    # Returns content of page as string, nil if the page does not exist.
    def get(page_title, options = {})
      page = make_api_request(options.merge(
        'action' => 'query',
        'prop'   => 'revisions',
        'rvprop' => 'content',
        'titles' => page_title
      )).first.elements['query/pages/page']

      page.elements['revisions/rev'].text || '' if valid_page?(page)
    end

    # Fetch latest revision ID of a MediaWiki page.  Does not follow redirects.
    #
    # [page_title] Page title to fetch
    # [options] Hash of additional options
    #
    # Returns revision ID as a string, nil if the page does not exist.
    def revision(page_title, options = {})
      page = make_api_request(options.merge(
        'action'  => 'query',
        'prop'    => 'revisions',
        'rvprop'  => 'ids',
        'rvlimit' => 1,
        'titles'  => page_title
      )).first.elements['query/pages/page']

      page.elements['revisions/rev'].attributes['revid'] if valid_page?(page)
    end

    # Render a MediaWiki page as HTML
    #
    # [page_title] Page title to fetch
    # [options] Hash of additional options
    #
    # Options:
    # * [:linkbase] supply a String to prefix all internal (relative) links with. '/wiki/' is assumed to be the base of a relative link
    # * [:noeditsections] strips all edit-links if set to +true+
    # * [:noimages] strips all +img+ tags from the rendered text if set to +true+
    #
    # Returns rendered page as string, or nil if the page does not exist
    def render(page_title, options = {})
      form_data = { 'action' => 'parse', 'page' => page_title }

      validate_options(options, %w[linkbase noeditsections noimages])

      rendered, parsed = nil,
        make_api_request(form_data).first.elements['parse']

      if parsed.attributes['revid'] != '0'
        rendered = parsed.elements['text'].text.gsub(/<!--(.|\s)*?-->/, '')

        # OPTIMIZE: unifiy the keys in +options+ like symbolize_keys! but w/o
        if linkbase = options['linkbase'] || options[:linkbase]
          rendered = rendered.gsub(/\shref="\/wiki\/([\w\(\)\-\.%:,]*)"/, ' href="' + linkbase + '/wiki/\1"')
        end

        if options['noeditsections'] || options[:noeditsections]
          rendered = rendered.gsub(/<span class="editsection">\[.+\]<\/span>/, '')
        end

        if options['noimages'] || options[:noimages]
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
    # * [:overwrite] Allow overwriting existing pages
    # * [:summary] Edit summary for history, string
    # * [:token] Use this existing edit token instead requesting a new one (useful for bulk loads)
    # * [:minor] Mark this edit as "minor" if true, mark this edit as "major" if false, leave major/minor status by default if not specified
    # * [:notminor] Mark this edit as "major" if true
    # * [:bot] Set the bot parameter (see http://www.mediawiki.org/wiki/API:Edit#Parameters).  Defaults to false.
    def create(title, content, options = {})
      form_data = {
        'action'  => 'edit',
        'title'   => title,
        'text'    => content,
        'summary' => options[:summary] || '',
        'token'   => get_token('edit', title)
      }

      if @options[:bot] || options[:bot]
        form_data.update('bot' => '1', 'assert' => 'bot')
      end

      form_data['minor']      = '1' if options[:minor]
      form_data['notminor']   = '1' if options[:minor] == false || options[:notminor]
      form_data['createonly'] = '' unless options[:overwrite]
      form_data['section']    = options[:section].to_s if options[:section]

      make_api_request(form_data)
    end

    # Edit page
    #
    # Same options as create, but always overwrites existing pages (and creates them if they don't exist already).
    def edit(title, content, options = {})
      create(title, content, { overwrite: true }.merge(options))
    end

    # Protect/unprotect a page
    #
    # Arguments:
    # * [title] Page title to protect, string
    # * [protections] Protections to apply, hash or array of hashes
    #
    #   Protections:
    #   * [:action] (required) The action to protect, string
    #   * [:group] (required) The group allowed to perform the action, string
    #   * [:expiry] The protection expiry as a GNU timestamp, string
    #
    # * [options] Hash of additional options
    #
    #   Options:
    #   * [:cascade] Protect pages included in this page, boolean
    #   * [:reason] Reason for protection, string
    #
    # Examples:
    # 1. mw.protect('Main Page', {:action => 'edit', :group => 'all'}, {:cascade => true})
    # 2. prt = [{:action => 'move', :group => 'sysop', :expiry => 'never'},
    #      {:action => 'edit', :group => 'autoconfirmed', :expiry => 'next Monday 16:04:57'}]
    #    mw.protect('Main Page', prt, {:reason => 'awesomeness'})
    #
    def protect(title, protections, options = {})
      case protections
        when Array
          # ok
        when Hash
          protections = [protections]
        else
          raise ArgumentError, "Invalid type '#{protections.class}' for protections"
      end

      valid_prt_options    = %w[action group expiry]
      required_prt_options = %w[action group]

      p, e = [], []

      protections.each { |prt|
        existing_prt_options = []

        prt.each_key { |opt|
          if valid_prt_options.include?(opt.to_s)
            existing_prt_options << opt.to_s
          else
            raise ArgumentError, "Unknown option '#{opt}' for protections"
          end
        }

        required_prt_options.each { |opt|
          unless existing_prt_options.include?(opt)
            raise ArgumentError, "Missing required option '#{opt}' for protections"
          end
        }

        p << "#{prt[:action]}=#{prt[:group]}"
        e << (prt.key?(:expiry) ? prt[:expiry].to_s : 'never')
      }

      validate_options(options, %w[cascade reason])

      form_data = {
        'action'      => 'protect',
        'title'       => title,
        'token'       => get_token('protect', title),
        'protections' => p.join('|'),
        'expiry'      => e.join('|')
      }

      form_data['cascade'] = '' if options[:cascade] == true
      form_data['reason']  = options[:reason].to_s if options[:reason]

      make_api_request(form_data)
    end

    # Move a page to a new title
    #
    # [from] Old page name
    # [to] New page name
    # [options] Hash of additional options
    #
    # Options:
    # * [:movesubpages] Move associated subpages
    # * [:movetalk] Move associated talkpages
    # * [:noredirect] Do not create a redirect page from old name.  Requires the 'suppressredirect' user right, otherwise MW will silently ignore the option and create the redirect anyway.
    # * [:reason] Reason for move
    # * [:watch] Add page and any redirect to watchlist
    # * [:unwatch] Remove page and any redirect from watchlist
    def move(from, to, options = {})
      validate_options(options, %w[movesubpages movetalk noredirect reason watch unwatch])

      make_api_request(options.merge(
        'action' => 'move',
        'from'   => from,
        'to'     => to,
        'token'  => get_token('move', from)
      ))
    end

    # Delete one page. (MediaWiki API does not support deleting multiple pages at a time.)
    #
    # [title] Title of page to delete
    # [options] Hash of additional options
    def delete(title, options = {})
      make_api_request(options.merge(
        'action' => 'delete',
        'title'  => title,
        'token'  => get_token('delete', title)
      ))
    end

    # Undelete all revisions of one page.
    #
    # [title] Title of page to undelete
    # [options] Hash of additional options
    #
    # Returns number of revisions undeleted, or zero if nothing to undelete
    def undelete(title, options = {})
      if token = get_undelete_token(title)
        make_api_request(options.merge(
          'action' => 'undelete',
          'title'  => title,
          'token'  => token
        )).first.elements['undelete'].attributes['revisions'].to_i
      else
        0 # No revisions to undelete
      end
    end

    # Get a list of matching page titles in a namespace
    #
    # [key] Search key, matched as a prefix (^key.*).  May contain or equal a namespace, defaults to main (namespace 0) if none given.
    # [options] Optional hash of additional options, eg. { 'apfilterredir' => 'nonredirects' }.  See http://www.mediawiki.org/wiki/API:Allpages
    #
    # Returns array of page titles (empty if no matches)
    def list(key, options = {})
      key, namespace = key.split(':', 2).reverse
      namespace = namespaces_by_prefix[namespace] || 0

      iterate_query('allpages', '//p', 'title', 'apfrom', options.merge(
        'list'        => 'allpages',
        'apprefix'    => key,
        'apnamespace' => namespace,
        'aplimit'     => @options[:limit]
      ))
    end

    # Get a list of pages that are members of a category
    #
    # [category] Name of the category
    # [options] Optional hash of additional options. See http://www.mediawiki.org/wiki/API:Categorymembers
    #
    # Returns array of page titles (empty if no matches)
    def category_members(category, options = {})
      iterate_query('categorymembers', '//cm', 'title', 'cmcontinue', options.merge(
        'cmtitle' => category,
        'cmlimit' => @options[:limit]
      ))
    end

    # Get a list of pages that link to a target page
    #
    # [title] Link target page
    # [filter] 'all' links (default), 'redirects' only, or 'nonredirects' (plain links only)
    # [options] Hash of additional options
    #
    # Returns array of page titles (empty if no matches)
    def backlinks(title, filter = 'all', options = {})
      iterate_query('backlinks', '//bl', 'title', 'blcontinue', options.merge(
        'bltitle'       => title,
        'blfilterredir' => filter,
        'bllimit'       => @options[:limit]
      ))
    end

    # Get a list of pages with matching content in given namespaces
    #
    # [key] Search key
    # [namespaces] Array of namespace names to search (defaults to main only)
    # [limit] Maximum number of hits to ask for (defaults to 500; note that Wikimedia Foundation wikis allow only 50 for normal users)
    # [max_results] Maximum total number of results to return
    # [options] Hash of additional options
    #
    # Returns array of page titles (empty if no matches)
    def search(key, namespaces = nil, limit = @options[:limit], max_results = @options[:max_results], options = {})
      titles, offset, form_data = [], 0, options.merge(
        'action'   => 'query',
        'list'     => 'search',
        'srwhat'   => 'text',
        'srsearch' => key,
        'srlimit'  => limit
      )

      if namespaces
        form_data['srnamespace'] = Array(namespaces).map! { |ns|
          namespaces_by_prefix[ns]
        }.join('|')
      end

      begin
        form_data['sroffset'] = offset if offset
        form_data['srlimit']  = [limit, max_results - offset.to_i].min

        res, offset = make_api_request(form_data, '//query-continue/search/@sroffset')

        titles += REXML::XPath.match(res, '//p').map { |x| x.attributes['title'] }
      end while offset && offset.to_i < max_results.to_i

      titles
    end

    # Get a list of users
    #
    # [options] Optional hash of options, eg. { 'augroup' => 'sysop' }.  See http://www.mediawiki.org/wiki/API:Allusers
    #
    # Returns array of user names (empty if no matches)
    def users(options = {})
      iterate_query('allusers', '//u', 'name', 'aufrom', options.merge(
        'aulimit' => @options[:limit]
      ))
    end

    # Get user contributions
    #
    # user: The user name
    # count: Maximum number of contributions to retreive, or nil for all
    # [options] Optional hash of options, eg. { 'ucnamespace' => 4 }.  See http://www.mediawiki.org/wiki/API:Usercontribs
    #
    # Returns array of hashes containing the "item" attributes defined here: http://www.mediawiki.org/wiki/API:Usercontribs
    def contributions(user, count = nil, options = {})
      result = []

      iterate_query('usercontribs', '//item', nil, 'uccontinue', options.merge(
        'ucuser'  => user,
        'uclimit' => @options[:limit]
      )) { |element|
        result << hash = {}
        element.attributes.each { |key, value| hash[key] = value }
      }

      count ? result.take(count) : result
    end

    # Upload a file, or get the status of pending uploads. Several
    # methods are available:
    #
    # * Upload file contents directly.
    # * Have the MediaWiki server fetch a file from a URL, using the
    #   'url' parameter
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
    # * 'comment'        - Upload comment. Also used as the initial page text for new files if 'text' is not specified.
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
    #   mw.upload('/path/to/local/file.jpg', 'filename' => 'RemoteFile.jpg')
    #   mw.upload(nil, 'filename' => 'RemoteFile2.jpg', 'url' => 'http://remote.com/server/file.jpg')
    #
    def upload(path, options = {})
      if options[:description]
        options['text'] = options.delete(:description)
      end

      if options[:target]
        options['filename'] = options.delete(:target)
      end

      if options[:summary]
        options['text'] ||= options[:summary]
        options['comment'] = options.delete(:summary)
      end

      options['comment'] ||= 'Uploaded by MediaWiki::Gateway'

      options['file'] = File.new(path) if path

      full_name = path || options['url']
      options['filename'] ||= File.basename(full_name) if full_name

      unless options['file'] || options['url'] || options['sessionkey']
        raise ArgumentError,
          "One of the 'file', 'url' or 'sessionkey' options must be specified!"
      end

      make_api_request(options.merge(
        'action' => 'upload',
        'token'  => get_token('edit', options['filename'])
      ))
    end

    # Checks if page is a redirect.
    #
    # [page_title] Page title to fetch
    #
    # Returns true if the page is a redirect, false if it is not or the page does not exist.
    def redirect?(page_title)
      page = make_api_request(
        'action' => 'query',
        'prop'   => 'info',
        'titles' => page_title
      ).first.elements['query/pages/page']

      !!(valid_page?(page) && page.attributes['redirect'])
    end

    # Get image list for given article[s].  Follows redirects.
    #
    # _article_or_pageid_ is the title or pageid of a single article
    # _imlimit_ is the maximum number of images to return (defaults to 200)
    # _options_ is the hash of additional options
    #
    # Example:
    #   images = mw.images('Gaborone')
    # _images_ would contain ['File:Gaborone at night.jpg', 'File:Gaborone2.png', ...]
    def images(article_or_pageid, imlimit = 200, options = {})
      form_data = options.merge(
        'action'    => 'query',
        'prop'      => 'images',
        'imlimit'   => imlimit,
        'redirects' => true
      )

      form_data[article_or_pageid.is_a?(Fixnum) ?
        'pageids' : 'titles'] = article_or_pageid

      xml = make_api_request(form_data).first

      if valid_page?(page = xml.elements['query/pages/page'])
        if xml.elements['query/redirects/r']
          # We're dealing with redirect here.
          images(page.attributes['pageid'].to_i, imlimit)
        else
          REXML::XPath.match(page, 'images/im').map { |x| x.attributes['title'] }
        end
      end
    end

    # Get list of interlanguage links for given article[s].  Follows redirects.  Returns a hash like { 'id' => 'Yerusalem', 'en' => 'Jerusalem', ... }
    #
    # _article_or_pageid_ is the title or pageid of a single article
    # _lllimit_ is the maximum number of langlinks to return (defaults to 500, the maximum)
    # _options_ is the hash of additional options
    #
    # Example:
    #   langlinks = mw.langlinks('Jerusalem')
    def langlinks(article_or_pageid, lllimit = 500, options = {})
      form_data = options.merge(
        'action'    => 'query',
        'prop'      => 'langlinks',
        'lllimit'   => lllimit,
        'redirects' => true
      )

      form_data[article_or_pageid.is_a?(Fixnum) ?
        'pageids' : 'titles'] = article_or_pageid

      xml = make_api_request(form_data).first

      if valid_page?(page = xml.elements['query/pages/page'])
        if xml.elements['query/redirects/r']
          # We're dealing with the redirect here.
          langlinks(page.attributes['pageid'].to_i, lllimit)
        elsif langl = REXML::XPath.match(page, 'langlinks/ll')
          langl.each_with_object({}) { |ll, links|
            links[ll.attributes['lang']] = ll.children[0].to_s
          }
        end
      end
    end

    # Convenience wrapper for _langlinks_ returning the title in language _lang_ (ISO code) for a given article of pageid, if it exists, via the interlanguage link
    #
    # Example:
    #
    #  langlink = mw.langlink_for_lang('Tycho Brahe', 'de')
    def langlink_for_lang(article_or_pageid, lang)
      langlinks(article_or_pageid)[lang]
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
    #     'Trooper.jpg', 'iiprop' => ['timestamp', 'user']
    #   ).each do |key, value|
    #     puts "#{key.inspect} => #{value.inspect}"
    #   end
    #
    # Output:
    #   "timestamp" => "2009-10-31T12:59:11Z"
    #   "user" => "Valdas"
    #
    def image_info(file_name_or_page_id, options = {})
      if options['iiprop'].respond_to?(:join)
        options['iiprop'] = options['iiprop'].join('|')
      end

      form_data = options.merge(
        'action'    => 'query',
        'prop'      => 'imageinfo',
        'redirects' => true
      )

      file_name_or_page_id.is_a?(Fixnum) ?
        form_data['pageids'] = file_name_or_page_id :
        form_data['titles']  = "File:#{file_name_or_page_id}"

      xml = make_api_request(form_data).first

      if valid_page?(page = xml.elements['query/pages/page'])
        if xml.elements['query/redirects/r']
          # We're dealing with redirect here.
          image_info(page.attributes['pageid'].to_i, options)
        else
          page.elements['imageinfo/ii'].attributes
        end
      end
    end

    # Download _file_name_ (without "File:" or "Image:" prefix). Returns file contents. All options are passed to
    # #image_info however options['iiprop'] is forced to url. You can still
    # set other options to control what file you want to download.
    def download(file_name, options = {})
      if attributes = image_info(file_name, options.merge('iiprop' => 'url'))
        RestClient.get(attributes['url'])
      end
    end

    # Imports a MediaWiki XML dump
    #
    # [xml] String or array of page names to fetch
    # [options] Hash of additional options
    #
    # Returns XML array <api><import><page/><page/>...
    # <page revisions="1"> (or more) means successfully imported
    # <page revisions="0"> means duplicate, not imported
    def import(xmlfile, options = {})
      make_api_request(options.merge(
        'action'  => 'import',
        'xml'     => File.new(xmlfile),
        'token'   => get_token('import', 'Main Page'), # NB: dummy page name
        'format'  => 'xml'
      ))
    end

    # Exports a page or set of pages
    #
    # [page_titles] String or array of page titles to fetch
    # [options] Hash of additional options
    #
    # Returns MediaWiki XML dump
    def export(page_titles, options = {})
      make_api_request(options.merge(
        'action'       => 'query',
        'titles'       => Array(page_titles).join('|'),
        'export'       => nil,
        'exportnowrap' => nil
      )).first
    end

    # Get the wiki's siteinfo as a hash. See http://www.mediawiki.org/wiki/API:Siteinfo.
    #
    # [options] Hash of additional options
    def siteinfo(options = {})
      res = make_api_request(options.merge(
        'action' => 'query',
        'meta'   => 'siteinfo'
      )).first

      REXML::XPath.first(res, '//query/general')
        .attributes.each_with_object({}) { |(k, v), h| h[k] = v }
    end

    # Get the wiki's MediaWiki version.
    #
    # [options] Hash of additional options passed to #siteinfo
    def version(options = {})
      siteinfo(options).fetch('generator', '').split.last
    end

    # Get a list of all known namespaces
    #
    # [options] Hash of additional options
    #
    # Returns array of namespaces (name => id)
    def namespaces_by_prefix(options = {})
      res = make_api_request(options.merge(
        'action' => 'query',
        'meta'   => 'siteinfo',
        'siprop' => 'namespaces'
      )).first

      REXML::XPath.match(res, '//ns').each_with_object({}) { |namespace, namespaces|
        prefix = namespace.attributes['canonical'] || ''
        namespaces[prefix] = namespace.attributes['id'].to_i
      }
    end

    # Get a list of all installed (and registered) extensions
    #
    # [options] Hash of additional options
    #
    # Returns array of extensions (name => version)
    def extensions(options = {})
      res = make_api_request(options.merge(
        'action' => 'query',
        'meta'   => 'siteinfo',
        'siprop' => 'extensions'
      )).first

      REXML::XPath.match(res, '//ext').each_with_object({}) { |extension, extensions|
        name = extension.attributes['name'] || ''
        extensions[name] = extension.attributes['version']
      }
    end

    # Sends e-mail to a user
    #
    # [user] Username to send mail to (name only: eg. 'Bob', not 'User:Bob')
    # [subject] Subject of message
    # [content] Content of message
    # [options] Hash of additional options
    #
    # Will raise a 'noemail' APIError if the target user does not have a confirmed email address, see http://www.mediawiki.org/wiki/API:E-mail for details.
    def email_user(user, subject, text, options = {})
      res = make_api_request(options.merge(
        'action'  => 'emailuser',
        'target'  => user,
        'subject' => subject,
        'text'    => text,
        'token'   => get_token('email', "User:#{user}")
      )).first

      res.elements['emailuser'].attributes['result'] == 'Success'
    end

    # Execute Semantic Mediawiki query
    #
    # [query] Semantic Mediawiki query
    # [params] Array of additional parameters or options, eg. mainlabel=Foo or ?Place (optional)
    # [options] Hash of additional options
    #
    # Returns result as an HTML string
    def semantic_query(query, params = [], options = {})
      unless smw_version = extensions['Semantic MediaWiki']
        raise MediaWiki::Exception, 'Semantic MediaWiki extension not installed.'
      end

      if smw_version.to_f >= 1.7
        make_api_request(options.merge(
          'action' => 'ask',
          'query'  => "#{query}|#{params.join('|')}"
        )).first
      else
        make_api_request(options.merge(
          'action' => 'parse',
          'prop'   => 'text',
          'text'   => "{{#ask:#{query}|#{params.push('format=list').join('|')}}}"
        )).first.elements['parse/text'].text
      end
    end

    # Create a new account
    #
    # [options] is +Hash+ passed as query arguments. See https://www.mediawiki.org/wiki/API:Account_creation#Parameters for more information.
    def create_account(options)
      make_api_request(options.merge('action' => 'createaccount')).first
    end

    # Sets options for currenlty logged in user
    #
    # [changes] a +Hash+ that will be transformed into an equal sign and pipe-separated key value parameter
    # [optionname] a +String+ indicating which option to change (optional)
    # [optionvalue] the new value for optionname - allows pipe characters (optional)
    # [reset] a +Boolean+ indicating if all preferences should be reset to site defaults (optional)
    # [options] Hash of additional options
    def options(changes = {}, optionname = nil, optionvalue = nil, reset = false, options = {})
      form_data = options.merge(
        'action' => 'options',
        'token'  => get_options_token
      )

      if changes.present?
        form_data['change'] = changes.map { |key, value| "#{key}=#{value}" }.join('|')
      end

      if optionname.present?
        form_data[optionname] = optionvalue
      end

      if reset
        form_data['reset'] = true
      end

      make_api_request(form_data).first
    end

    # Set groups for a user
    #
    # [user] Username of user to modify
    # [groups_to_add] Groups to add user to, as an array or a string if a single group (optional)
    # [groups_to_remove] Groups to remove user from, as an array or a string if a single group (optional)
    # [options] Hash of additional options
    def set_groups(user, groups_to_add = [], groups_to_remove = [], comment = '', options = {})
      token = get_userrights_token(user)
      userrights(user, token, groups_to_add, groups_to_remove, comment, options)
    end

    # Review current revision of an article (requires FlaggedRevisions extension, see http://www.mediawiki.org/wiki/Extension:FlaggedRevs)
    #
    # [title] Title of article to review
    # [flags] Hash of flags and values to set, eg. { 'accuracy' => '1', 'depth' => '2' }
    # [comment] Comment to add to review (optional)
    # [options] Hash of additional options
    def review(title, flags, comment = 'Reviewed by MediaWiki::Gateway', options = {})
      raise APIError.new('missingtitle', "Article #{title} not found") unless revid = revision(title)

      form_data = options.merge(
        'action'  => 'review',
        'revid'   => revid,
        'token'   => get_token('edit', title),
        'comment' => comment
      )

      flags.each { |k, v| form_data["flag_#{k}"] = v }

      make_api_request(form_data).first
    end

    # Make a custom query
    #
    # [options] query options
    #
    # Returns the REXML::Element object as result
    #
    # Example:
    #   def creation_time(pagename)
    #     res = bot.custom_query(:prop => :revisions,
    #                            :titles => pagename,
    #                            :rvprop => :timestamp,
    #                            :rvdir => :newer,
    #                            :rvlimit => 1)
    #     timestr = res.get_elements('*/*/*/rev')[0].attribute('timestamp').to_s
    #     time.parse(timestr)
    #   end
    #
    def custom_query(options)
      form_data = {}
      options.each { |k, v| form_data[k.to_s] = v.to_s }
      make_api_request(form_data.merge('action' => 'query')).first.elements['query']
    end

    private

    # Fetch token (type 'delete', 'edit', 'email', 'import', 'move', 'protect')
    def get_token(type, page_titles)
      res = make_api_request(
        'action'  => 'query',
        'prop'    => 'info',
        'intoken' => type,
        'titles'  => page_titles
      ).first

      unless token = res.elements['query/pages/page'].attributes[type + 'token']
        raise Unauthorized.new "User is not permitted to perform this operation: #{type}"
      end

      token
    end

    def get_undelete_token(page_titles)
      res = make_api_request(
        'action' => 'query',
        'list'   => 'deletedrevs',
        'prop'   => 'info',
        'drprop' => 'token',
        'titles' => page_titles
      ).first

      if res.elements['query/deletedrevs/page']
        unless token = res.elements['query/deletedrevs/page'].attributes['token']
          raise Unauthorized.new("User is not permitted to perform this operation: #{type}")
        end

        token
      end
    end

    # User rights management (aka group assignment)
    def get_userrights_token(user)
      res = make_api_request(
        'action'  => 'query',
        'list'    => 'users',
        'ustoken' => 'userrights',
        'ususers' => user
      ).first

      token = res.elements['query/users/user'].attributes['userrightstoken']

      @log.debug("RESPONSE: #{res.to_s}")

      unless token
        if res.elements['query/users/user'].attributes['missing']
          raise APIError.new('invaliduser', "User '#{user}' was not found (get_userrights_token)")
        else
          raise Unauthorized.new("User '#{@username}' is not permitted to perform this operation: get_userrights_token")
        end
      end

      token
    end

    def get_options_token
      res = make_api_request('action' => 'tokens', 'type' => 'options').first
      res.elements['tokens'].attributes['optionstoken']
    end

    def userrights(user, token, groups_to_add, groups_to_remove, reason, options = {})
      # groups_to_add and groups_to_remove can be a string or an array. Turn them into MediaWiki's pipe-delimited list format.
      if groups_to_add.is_a?(Array)
        groups_to_add = groups_to_add.join('|')
      end

      if groups_to_remove.is_a?(Array)
        groups_to_remove = groups_to_remove.join('|')
      end

      make_api_request(options.merge(
        'action' => 'userrights',
        'user'   => user,
        'token'  => token,
        'add'    => groups_to_add,
        'remove' => groups_to_remove,
        'reason' => reason
      )).first
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
    # [form_data] hash or string of attributes to post
    # [continue_xpath] XPath selector for query continue parameter
    # [retry_count] Counter for retries
    #
    # Returns XML document
    def make_api_request(form_data, continue_xpath = nil, retry_count = 1)
      if form_data.is_a?(Hash)
        form_data['format'] = 'xml'
        form_data['maxlag'] = @options[:maxlag]
      end

      http_send(@wiki_url, form_data, @headers.merge(cookies: @cookies)) { |response, &block|
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
      }
    end

    # Execute the HTTP request using either GET or POST as appropriate
    def http_send url, form_data, headers, &block
      opts = @http_options.merge(url: url, headers: headers)
      opts[:method] = form_data['action'] == 'query' ? :get : :post
      opts[:method] == :get ? headers[:params] = form_data : opts[:payload] = form_data

      log.debug("#{opts[:method].upcase}: #{form_data.inspect}, #{@cookies.inspect}")

      RestClient::Request.execute(opts, &block)
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
