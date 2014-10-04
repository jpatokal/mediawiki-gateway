module MediaWiki

  class Gateway

    module Files

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

    end

    include Files

  end

end
