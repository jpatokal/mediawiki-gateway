module MediaWiki
  class << self

    # Extract path leading up to subpage.  If title does not contain a subpage, returns nil.
    #
    # Examples:
    # get_path_to_subpage("Namespace:Foo/Bar/Baz") -> "Namespace:Foo/Bar"
    # get_path_to_subpage("Namespace:Foo") -> nil
    #
    # [title] Page name string in Wiki format 
    def get_path_to_subpage(title)
      return nil unless title and title.include? '/'
      parts = title.split(/\/([^\/]*)$/).first
    end

    # Extract subpage name.  If there is no hierarchy above, return page name.
    #
    # Examples:
    # get_subpage("Namespace:Foo/Bar/Baz") -> "Baz"
    # get_subpage("Namespace:Foo") -> "Namespace:Foo"
    #
    # [title] Page name string in Wiki format 
    def get_subpage(title)
      title.split('/').last if title
    end

    # Convert URL-ized page name ("getting_there_%26_away") into Wiki display format page name ("getting there & away")
    # [wiki] Page name string in URL
    def uri_to_wiki(uri)
      CGI.unescape(uri).tr('_', ' ') if uri
    end
    
    # Convert a Wiki page name ("getting there & away") to URI-safe format ("getting_there_%26_away"),
    # taking care not to mangle slashes
    # [wiki] Page name string in Wiki format
    def wiki_to_uri(wiki)
      wiki.to_s.split('/').map {|chunk| CGI.escape(chunk.tr(' ', '_')) }.join('/') if wiki
    end

    # Return current version of MediaWiki::Gateway
    def version
      MediaWiki::VERSION
    end
  end
  
end
