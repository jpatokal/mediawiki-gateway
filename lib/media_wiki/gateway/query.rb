module MediaWiki

  class Gateway

    module Query

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
          }.compact.join('|')
        end

        begin
          form_data['sroffset'] = offset if offset
          form_data['srlimit']  = [limit, max_results - offset.to_i].min

          res, offset = make_api_request(form_data, '//query-continue/search/@sroffset')

          titles += REXML::XPath.match(res, '//p').map { |x| x.attributes['title'] }
        end while offset && offset.to_i < max_results.to_i

        titles
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
          send_request(options.merge(
            'action' => 'ask',
            'query'  => [query, *params].join('|')
          ))
        else
          send_request(options.merge(
            'action' => 'parse',
            'prop'   => 'text',
            'text'   => "{{#ask:#{[query, 'format=list', *params].join('|')}}}"
          )).elements['parse/text'].text
        end
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
        send_request(form_data.merge('action' => 'query')).elements['query']
      end

    end

    include Query

  end

end
