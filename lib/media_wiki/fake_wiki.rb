require 'sinatra/base'
require 'sham_rack'
require 'nokogiri'

module MediaWiki

  # A simple Rack app that stubs out a web service, for testing.

  module FakeWiki

    class App < Sinatra::Base

      set :show_exceptions, false
      set :environment, :development

      def initialize
        reset
        super
      end

      def reset
        @sequence_id = 0

        @users = {}
        add_user('atlasmw', 'wombat', 'local', true)
        add_user('nonadmin', 'sekrit', 'local', false)
        add_user('ldapuser', 'ldappass', 'ldapdomain', false)

        @pages = ApiPages.new
        @pages.add('Main Page', 'Content')
        @pages.add('Main 2', 'Content')
        @pages.add('Empty', '')
        @pages.add('Level/Level/Index', '{{#include:Foo}} {{#include:Bar}}')
        @pages.add_namespace(100, "Book")
        @pages.add('Book:Italy', 'Introduction')
        @pages.add_namespace(200, "Sandbox")
        @pages.add('Foopage', 'Content')
        @pages.add('Redirect', '#REDIRECT', true)

        @extensions = { 'FooExtension' => 'r1', 'BarExtension' => 'r2', 'Semantic MediaWiki' => '1.5' }

        @logged_in_users = []
      end

      def next_id
        @sequence_id += 1
      end

      def add_user(username, password, domain, is_admin)
        @users[username] = {
          :userid => next_id,
          :username => username,
          :password => password,
          :domain => domain,
          :is_admin => is_admin
        }
      end

      def logged_in(username)
        @logged_in_users.include?(username)
      end

      get "/w/api.php" do
        handle_request if params[:action] == 'query'
      end

      post "/w/api.php" do
        handle_request
      end

      def handle_request
        begin
          if params[:maxlag].to_i < 0
            maxlag = params[:maxlag].to_i
            # Some versions of mediawiki return an XML response with HTTP 200.
            if params[:maxlag_code].to_i == 200
              content_type "application/xml"
              return maxlag_response(maxlag.abs)
            else
              # The documentation states that mediawiki should return
              # a text/plain response with HTTP 503.
              halt(503, "Maxlag exceeded")
            end
          end

          @token = ApiToken.new(params)
          action = params[:action]
          if respond_to?(action)
            content_type "application/xml"
            return send(action)
          end

          halt(404, "Page not found")
        rescue ApiError => e
          return api_error_response(e.code, e.message)
        end
      end

      def import
        @token.validate_admin

        api_response do |_|
          _.import do
            _.page(nil, :title => "Main Page", :ns => 0, :revisions => 0)
            _.page(nil, :title => "Template:Header", :ns => 10, :revisions => 1)
          end
        end
      end

      def validate_page_overwrite(current_page)
        if current_page && params[:createonly]
          raise ApiError.new("articleexists", "The article you tried to create has been created already")
        end
      end

      def edit
        @token.validate

        title = params[:title]
        current_page = @pages.get(title)
        validate_page_overwrite(current_page)

        new_page = @pages.add(title, params[:text])
        page_info = {:result => "Success", :pageid => new_page[:pageid], :title => new_page[:title], :newrevid => new_page[:pageid]}
        if current_page
          page_info.merge!(:oldrevid => current_page[:pageid])
        else
          page_info.merge!(:new => "", :oldrevid => 0)
        end

        api_response do |_|
          _.edit(nil, page_info)
        end
      end

      def delete
        @token.validate_admin

        title = params[:title]
        raise ApiError.new("missingtitle", "The page you requested doesn't exist") unless @pages.get(title)
        @pages.delete(title)

        api_response do |_|
          _.delete(nil, {:title => title, :reason => "Default reason"})
        end
      end

      def undelete
        @token.validate_admin

        title = params[:title]
        revisions = @pages.undelete(title)
        api_response do |_|
          _.undelete(nil, {:title => title, :revisions => revisions})
        end
      end

      def upload
        @token.validate

        filename = params[:filename]
        @pages.add(filename, params[:file])
        api_response do |_|
          _.upload(nil, {:filename => filename, :result => "Success"})
        end
      end

      def parse
        page = @pages.get(params[:page])
        api_response do |_|
          _.parse({ :revid => page ?  page[:pageid] : 0}) do
            if params[:page] == "Foopage"
              _.text!('Sample <B>HTML</B> content.' \
                '<img width="150" height="150" class="thumbimage" src="http://upload.wikimedia.org/foo/Ruby_logo.svg" alt="Ruby logo.svg"/>' \
                '<span class="editsection">[<a title="Edit section: Nomenclature" href="/w/index.php?title=Seat_of_local_government&amp;action=edit&amp;section=1">edit</a>]</span>' \
                '<a title="Interpreted language" href="/wiki/Interpreted_language">interpreted language</a>'
              )
            else
              _.text!('Sample <B>HTML</B> content.')
            end
          end
        end
      end

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
        Nokogiri::XML::Builder.new do |_|
          _.mediawiki do
            requested_page_titles.each do |requested_title|
              page = @pages.get(requested_title)
              _.page do
                _.title(page[:title])
                _.id(page[:pageid])
                _.revision do
                  _.id(page[:pageid])
                  _.text!(page[:content])
                end
              end
            end
          end
        end.to_xml
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
              @pages.search(params[:srsearch], namespaces).first(params[:srlimit].to_i).each do |key, page|
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
        if siteinfo_type = params[:siprop]
          return send(siteinfo_type) if respond_to?(siteinfo_type)
          halt(404, "Page not found")
        else
          api_response do |_|
            _.query do
              _.general(generator: "MediaWiki #{MediaWiki::VERSION}")
            end
          end
        end
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

      def api_response(api_attr = {}, &block)
        Nokogiri::XML::Builder.new do |_|
          _.api(api_attr, &block)
        end.to_xml
      end

      def api_error_response(code, info)
        api_response do |_|
          _.error(nil,
                  :code => code,
                  :info => info)
        end
      end

      def query_pages
        api_response do |_|
          _.query do
            _.pages do
              requested_page_titles.each do |title|
                yield(_, title, @pages.get(title))
              end
            end
          end
        end
      end

      def get_info
        query_pages do |_, title, page|
          attributes = { :title => title, :ns => '0'}
          if page.nil?
            attributes[:missing] = ""
          else
            attributes[:redirect] = "" if page[:redirect]
          end
          _.page(nil, attributes)
        end
      end

      def get_revisions
        query_pages do |_, title, page|
          if page.nil?
            _.page(nil, { :title => title, :ns => '0', :missing => "" })
          else
            page = page.dup
            content = page.delete(:content)
            _.page(page.merge({ :ns => 0 })) do
              _.revisions do
                _.rev(content)
              end
            end
          end
        end
      end

      def user
        username = request.cookies['login']
        @users[username] if logged_in(username)
      end

      def requested_page_titles
        params[:titles].split("|")
      end

      def tokens
        @token.request(user)

        api_response do |_|
          _.tokens(:optionstoken => @token.optionstoken)
        end
      end

      def get_token
        token_str = @token.request(user)
        query_pages do |_, title, page|
          page = page ? page.dup : {}
          page[params[:intoken] + "token"] = token_str if token_str
          _.page(nil, page.merge({ :ns => 0 }))
        end
      end

      def get_undelete_token
        @token.set_type 'undelete'
        token_str = @token.request(user)
        api_response do |_|
          _.query do
            _.deletedrevs do
              requested_page_titles.select {|title| ! @pages.get(title) }.each do |title|
                _.page(nil, { :title => title, :token => token_str })
              end
            end
          end
        end
      end

      def get_userrights_token(username)
        @token.set_type 'userrights'
        token_str = @token.request(user)

        user_to_manage = @users[username]

        if user_to_manage
          api_response do |_|
            _.query do
              _.users do
                _.user(nil, { :name => user_to_manage[:username], :userrightstoken => token_str })
              end
            end
          end
        else
          api_response do |_|
            _.error(nil, { :code => 'nosuchuser', :info => "The user '#{params[:ususer].to_s}' does not exist"} )
          end
        end
      end

      def login
        user = @users[params[:lgname]]
        if user and user[:domain] == params[:lgdomain]
          if params[:lgpassword] == user[:password]
            @logged_in_users << user[:username]
            response.set_cookie('login', user[:username])
            result = { :result => "Success", :lguserid => "1", :lgusername => "Atlasmw"}
          else
            result = { :result => "WrongPass" }
          end
        else
          result = { :result => "NotExists" }
        end

        api_response do |_|
          _.login(nil, result)
        end
      end

      def createaccount
        api_response do |_|
          @token.request(user)

          if params[:token] && !params[:token].empty?
            @token.validate_admin
            add_user(params[:name], params[:password], 'local', false)
            _.createaccount(:token => @token.createusertoken, :userid => @users.length, :username => params[:name], :result => 'success')
          else
            _.createaccount(:token => @token.createusertoken, :result => 'needtoken')
          end
        end
      end

      def options
        api_response(:options => 'success')
      end

      def userrights
        api_response do |_|
          _.userrights({:user => params[:user]}) do
            _.removed do
              params[:remove].split('|').each do |removed_group|
                _.group(removed_group)
              end
            end
            _.added do
              params[:add].split('|').each do |added_group|
                _.group(added_group)
              end
            end
          end
        end
      end

      def maxlag_response(maxlag)
        api_response do |_|
          _.error(:code => "maxlag", :info => "Waiting for 127.0.0.1: #{maxlag} seconds lagged") do
            _.text("See https://en.wikipedia.org/w/api.php for API usage")
          end
        end
      end

    end

    class WikiPage

      def initialize(options={})
        options.each { |k, v| send("#{k}=", v) }
      end

      attr_accessor :content, :author

    end

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
        raise ApiError.new("srparam-search", "empty search string is not allowed") if searchkey.empty?
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
          raise ApiError.new("notoken", "The token parameter must be set")
        end
      end

      def validate_admin
        validate
        if @token_str != ADMIN_TOKEN
          raise ApiError.new("badtoken", "Invalid token")
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
      alias_method :createusertoken, :importtoken

      def edittoken
        if @user
          REGULAR_TOKEN
        else
          BLANK_TOKEN
        end
      end

      alias_method :optionstoken, :edittoken

    end

    class ApiError < StandardError

      attr_reader :code, :message

      def initialize(code, message)
        @code = code
        @message = message
      end

    end

    module RSpecAdapter

      ADDRESS = 'dummy-wiki.example'

      def self.enhance(config, *args)
        ShamRack.mount($fake_media_wiki = App.new!, ADDRESS)

        config.before(*args) {
          @gateway = Gateway.new("http://#{ADDRESS}/w/api.php")
          $fake_media_wiki.reset
        }
      end

    end

  end

end
