
module FakeMediaWiki
  
  module QueryHandling

    def action
      [:userrights].each do |action_type|
        return send(action_type)
      end
      halt(404, "Page not found")
    end

    def query
      [:prop, :export, :list, :meta].each do |query_type|
        return send(query_type) if params[query_type]
      end
      halt(404, "Page not found")
    end

    def prop
      return get_revisions if params[:prop] == "revisions"
      return get_undelete_token if params[:drprop] == 'token'
      return get_token if params[:intoken]
      return get_info if params[:prop] == "info"
    end

    def export
      builder do |_|
        _.mediawiki do
          requested_page_titles.each do |requested_title|
            page = @pages.get(requested_title)
            _.page do
              _.title(page[:title])
              _.id(page[:pageid])
              _.revision do
                _.id(page[:pageid])
                _.text(page[:content])
              end
            end
          end
        end
      end
    end
    
    def list
      list_type = params[:list].to_sym

      # api.php?action=query&list=users&ususers=Bob&ustoken=userrights
      if list_type == :users && params[:ustoken] && params[:ususers]
        # This "list" is actually a request for a user rights token
        return get_userrights_token(params[:ususers])
      end
      
      # This is a real list
      return send(list_type) if respond_to?(list_type)
      halt(404, "Page not found")
    end

    def allpages
      api_response do |_|
        _.query do
          _.allpages do
            prefix = params[:apprefix]
            namespace = @pages.namespaces_by_id[params[:apnamespace].to_i]
            prefix = "#{namespace}:#{prefix}" unless namespace.empty?
            @pages.list(prefix).each do |key, page|
              _.p(nil, { :title => page[:title], :ns => page[:namespace], :id => page[:pageid] })
            end
          end
        end
      end
    end

    def search
      api_response do |_|
        _.query do
          _.search do
            namespaces = params[:srnamespace] ? params[:srnamespace].split('|') : [ "0" ]
            @pages.search(params[:srsearch], namespaces).each do |key, page|
              _.p(nil, { :title => page[:title], :ns => page[:namespace], :id => page[:pageid] })
            end
          end
        end
      end
    end
    
    def meta
      meta_type = params[:meta].to_sym
      return send(meta_type) if respond_to?(meta_type)
      halt(404, "Page not found")
    end
    
    def siteinfo
      siteinfo_type = params[:siprop].to_sym
      return send(siteinfo_type) if respond_to?(siteinfo_type)
      halt(404, "Page not found")
    end
    
    def namespaces
      api_response do |_|
        _.query do
          _.namespaces do
            @pages.namespaces_by_prefix.each do |prefix, id|
              attr = { :id => id }
              attr[:canonical] = prefix unless prefix.empty?
              _.ns(prefix, attr)
            end
          end
        end
      end
    end

    def extensions
      api_response do |_|
        _.query do
          _.extensions do
            @extensions.each do |name, version|
              attr = { :version => version }
              attr[:name] = name unless name.empty?
              _.ext(name, attr)
            end
          end
        end
      end
    end
    
  end

end
