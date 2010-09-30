module MediaWiki

  class << self

    def version
      "0.0.1"
    end
    
    # Convert a Wiki page name ("getting there & away") to URI-safe format ("getting_there_%26_away"),
    # taking care not to mangle slashes
    # [wiki] Page name string in Wiki format
    def wiki_to_uri(wiki)
      wiki.to_s.split('/').map {|chunk| CGI.escape(chunk.tr(' ', '_')) }.join('/') if wiki
    end

  end
  
end
