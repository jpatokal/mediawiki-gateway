module MediaWiki

  class Gateway

    module Site

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

    end

    include Site

  end

end
