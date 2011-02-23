require 'rubygems'
require 'sinatra/base'
require 'spec/fake_media_wiki/api_pages'
require 'spec/fake_media_wiki/query_handling'

# A simple Rack app that stubs out a web service, for testing.

module FakeMediaWiki

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

      @extensions = { 'FooExtension' => 'r1', 'BarExtension' => 'r2' }
      
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

    post "/w/api.php" do
      begin
        halt(503, "Maxlag exceeded") if params[:maxlag].to_i < 0 

        @token = ApiToken.new(params)
        action = params[:action]
        if respond_to?(action)
          content_type "application/xml"
          return send(action)
        end
  
        halt(404, "Page not found")
      rescue FakeMediaWiki::ApiError => e
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
        raise FakeMediaWiki::ApiError.new("articleexists", "The article you tried to create has been created already")
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
      raise FakeMediaWiki::ApiError.new("missingtitle", "The page you requested doesn't exist") unless @pages.get(title)
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
            _.text('Sample <B>HTML</B> content.' \
              '<img width="150" height="150" class="thumbimage" src="http://upload.wikimedia.org/foo/Ruby_logo.svg" alt="Ruby logo.svg"/>' \
              '<span class="editsection">[<a title="Edit section: Nomenclature" href="/w/index.php?title=Seat_of_local_government&amp;action=edit&amp;section=1">edit</a>]</span>' \
              '<a title="Interpreted language" href="/wiki/Interpreted_language">interpreted language</a>'
            )
          else
            _.text('Sample <B>HTML</B> content.')
          end
        end
      end
    end
    
    include QueryHandling

    def api_response
      builder do |_|
        _.api do |_|
          yield(_)
        end
      end
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

  end

  class WikiPage
    
    def initialize(options={})
      options.each { |k, v| send("#{k}=", v) }
    end
    
    attr_accessor :content, :author

  end

end
