module FakeMediaWiki

  class ApiPages

    def initialize
      @page_id = 0
      @pages = {}
      @namespaces = { "" => 0 }
    end
    
    def add_namespace(id, prefix)
      @namespaces[prefix] = id
    end

    def namespaces_by_prefix
      @namespaces
    end

    def namespaces_by_id
      @namespaces.invert
    end
  
    def add(title, content, redirect=false)
      @page_id += 1
      dummy, prefix = title.split(":", 2).reverse
      @pages[title] = {
        :pageid => @page_id,
        :namespace => namespaces_by_prefix[prefix || ""],
        :title => title,
        :content => content,
        :redirect => redirect
      }
    end
    
    def get(title)
      @pages[title]
    end
    
    def list(prefix) 
      @pages.select do |key, page|
        key =~ /^#{prefix}/
      end
    end

    def search(searchkey, namespaces)
      raise FakeMediaWiki::ApiError.new("srparam-search", "empty search string is not allowed") if searchkey.empty?
      @pages.select do |key, page|
        page[:content] =~ /#{searchkey}/ and namespaces.include? page[:namespace].to_s
      end
    end
    
    def delete(title)
      @pages.delete(title)
    end

    def undelete(title)
      if @pages[title]
        0
      else
        add(title, "Undeleted content")
        1
      end
    end
  end

  class ApiToken
    ADMIN_TOKEN   = "admin_token+\\" 
    REGULAR_TOKEN = "regular_token+\\"
    BLANK_TOKEN   = "+\\"

    def initialize(params)
      @token_str = params[:token]
      @token_in = params[:intoken]
    end
    
    def set_type(type)
      @token_in = type
    end
    
    def validate
      unless @token_str
        raise FakeMediaWiki::ApiError.new("notoken", "The token parameter must be set")
      end
    end

    def validate_admin
      validate
      if @token_str != ADMIN_TOKEN
        raise FakeMediaWiki::ApiError.new("badtoken", "Invalid token")
      end
    end
    
    def request(user)
      @user = user
      respond_to?(requested_token_type) ? send(requested_token_type) : nil
    end
       
    def requested_token_type
      "#{@token_in}token".to_sym
    end

    def importtoken
      if @user && @user[:is_admin]
        ADMIN_TOKEN
      else
        nil
      end
    end
    alias_method :deletetoken, :importtoken
    alias_method :undeletetoken, :importtoken
    alias_method :userrightstoken, :importtoken
    
    def edittoken
      if @user
        REGULAR_TOKEN
      else
        BLANK_TOKEN
      end
    end
  end

  class ApiError < StandardError
    
    attr_reader :code, :message

    def initialize(code, message)
      @code = code
      @message = message
    end

  end
  
end
