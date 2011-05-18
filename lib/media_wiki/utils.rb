module MediaWiki
  class << self

    # Extract base name.  If there are no subpages, return page name.
    #
    # Examples:
    # get_base_name("Namespace:Foo/Bar/Baz") -> "Namespace:Foo"
    # get_base_name("Namespace:Foo") -> "Namespace:Foo"
    #
    # [title] Page name string in Wiki format 
    def get_base_name(title)
      title.split('/').first if title
    end

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

    # Convert URL-ized page name ("getting_there_%26_away") into Wiki display format page name ("Getting there & away").
    # Also capitalizes first letter, replaces underscores with spaces and strips out any illegal characters (#<>[]|{}, cf. http://meta.wikimedia.org/wiki/Help:Page_name#Restrictions).
    #
    # [wiki] Page name string in URL
    def uri_to_wiki(uri)
      upcase_first_char(CGI.unescape(uri).tr('_', ' ').tr('#<>[]|{}', '')) if uri
    end
    
    # Convert a Wiki page name ("Getting there & away") to URI-safe format ("Getting_there_%26_away"),
    # taking care not to mangle slashes or colons
    # [wiki] Page name string in Wiki format
    def wiki_to_uri(wiki)
      wiki.to_s.split('/').map {|chunk| CGI.escape(CGI.unescape(chunk).tr(' ', '_')) }.join('/').gsub('%3A', ':') if wiki
    end

    # Return current version of MediaWiki::Gateway
    def version
      MediaWiki::VERSION
    end
    
    private
    
    def upcase_first_char(str)
      [ ActiveSupport::Multibyte::Chars.new(str.mb_chars.slice(0,1)).upcase.to_s, str.mb_chars.slice(1..-1) ].join
    end
  end
  
end
