module MediaWiki

  class Gateway

    module Pages

      # Fetch MediaWiki page in MediaWiki format.  Does not follow redirects.
      #
      # [page_title] Page title to fetch
      # [options] Hash of additional options
      #
      # Returns content of page as string, nil if the page does not exist.
      def get(page_title, options = {})
        page = send_request(options.merge(
          'action' => 'query',
          'prop'   => 'revisions',
          'rvprop' => 'content',
          'titles' => page_title
        )).elements['query/pages/page']

        page.elements['revisions/rev'].text || '' if valid_page?(page)
      end

      # Fetch latest revision ID of a MediaWiki page.  Does not follow redirects.
      #
      # [page_title] Page title to fetch
      # [options] Hash of additional options
      #
      # Returns revision ID as a string, nil if the page does not exist.
      def revision(page_title, options = {})
        page = send_request(options.merge(
          'action'  => 'query',
          'prop'    => 'revisions',
          'rvprop'  => 'ids',
          'rvlimit' => 1,
          'titles'  => page_title
        )).elements['query/pages/page']

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

        rendered, parsed = nil, send_request(form_data).elements['parse']

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

        send_request(form_data)
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

        send_request(form_data)
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

        send_request(options.merge(
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
        send_request(options.merge(
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
          send_request(options.merge(
            'action' => 'undelete',
            'title'  => title,
            'token'  => token
          )).elements['undelete'].attributes['revisions'].to_i
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

      # Checks if page is a redirect.
      #
      # [page_title] Page title to fetch
      #
      # Returns true if the page is a redirect, false if it is not or the page does not exist.
      def redirect?(page_title)
        page = send_request(
          'action' => 'query',
          'prop'   => 'info',
          'titles' => page_title
        ).elements['query/pages/page']

        !!(valid_page?(page) && page.attributes['redirect'])
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

        xml = send_request(form_data)

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

        send_request(form_data)
      end

      private

      def get_undelete_token(page_titles)
        res = send_request(
          'action' => 'query',
          'list'   => 'deletedrevs',
          'prop'   => 'info',
          'drprop' => 'token',
          'titles' => page_titles
        )

        if res.elements['query/deletedrevs/page']
          unless token = res.elements['query/deletedrevs/page'].attributes['token']
            raise Unauthorized.new("User is not permitted to perform this operation: #{type}")
          end

          token
        end
      end

    end

    include Pages

  end

end
