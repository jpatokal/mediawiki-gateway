module MediaWiki

  class << self

    # TODO sync this automatically with Gem version
    def version
      "0.2.1"
    end
    
    # Convert a Wiki page name ("getting there & away") to URI-safe format ("getting_there_%26_away"),
    # taking care not to mangle slashes
    # [wiki] Page name string in Wiki format
    def wiki_to_uri(wiki)
      wiki.to_s.split('/').map {|chunk| CGI.escape(chunk.tr(' ', '_')) }.join('/') if wiki
    end

    # Convert URL-ized page name ("getting_there_%26_away") into Wiki display format page name ("getting there & away")
    # [wiki] Page name string in URL
    def uri_to_wiki(uri)
      CGI.unescape(uri).tr('_', ' ') if uri
    end

  end
  
end
