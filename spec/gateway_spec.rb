require 'spec_helper'

# Kickstart fake media wiki app
require 'sham_rack'
require 'spec/fake_media_wiki/app'
$fake_media_wiki = FakeMediaWiki::App.new
unless $fake_media_wiki.instance_of? FakeMediaWiki::App
  # This is a horrible workaround for some bizarre conflict with later versions of ShamRack/Rack/Sinatra/Builder/...
  $fake_media_wiki = $fake_media_wiki.instance_eval('@app').instance_eval('@app').app.app.app.app.app
end
ShamRack.mount($fake_media_wiki, 'dummy-wiki.example')

describe MediaWiki::Gateway do

  before do
    @gateway = MediaWiki::Gateway.new('http://dummy-wiki.example/w/api.php')
    $fake_media_wiki.reset
  end

  describe '#login' do

    describe "with a valid username & password" do

      before do
        @gateway.login('atlasmw', 'wombat')
      end

      it "should login successfully with the default domain" do
        $fake_media_wiki.logged_in('atlasmw').should == true
      end

    end

    describe "with a valid username, password and domain" do

      before do
        @gateway.login('ldapuser', 'ldappass', 'ldapdomain')
      end

      it "should login successfully" do
        $fake_media_wiki.logged_in('ldapuser').should == true
      end

    end

    describe "with an non-existent username" do

      it "should raise an error" do
        lambda do
          @gateway.login('bogususer', 'sekrit')
        end.should raise_error(MediaWiki::Unauthorized)
      end

    end

    describe "with an incorrect password" do

      it "should raise an error" do
        lambda do
          @gateway.login('atlasmw', 'sekrit')
        end.should raise_error(MediaWiki::Unauthorized)
      end

    end

    describe "with an incorrect domain" do

      it "should raise an error" do
        lambda do
          @gateway.login('atlasmw', 'wombat', 'bogusdomain')
        end.should raise_error(MediaWiki::Unauthorized)
      end

    end

  end

  describe "#get_token" do

    describe "when not logged in" do

      describe "requesting an edit token" do

        before do
          @token = @gateway.send(:get_token, 'edit', 'Main Page')
        end

        it "should return a blank token" do
          @token.should_not == nil
          @token.should == "+\\"
        end

      end

      describe "requesting an import token" do

        it "should raise an error" do
          lambda do
            @gateway.send(:get_token, 'import', 'Main Page')
          end.should raise_error(MediaWiki::Unauthorized)
        end

      end

    end

    describe "when logged in as admin user" do

      before do
        @gateway.login('atlasmw', 'wombat')
      end

      describe "requesting an edit token for a single page" do

        before do
          @token = @gateway.send(:get_token, 'edit', 'Main Page')
        end

        it "should return a token" do
          @token.should_not == nil
          @token.should_not == "+\\"
        end

      end

      describe "requesting an edit token for multiple pages" do

        before do
          @token = @gateway.send(:get_token, 'edit', "Main Page|Another Page")
        end

        it "should return a token" do
          @token.should_not == nil
          @token.should_not == "+\\"
        end

      end

      describe "requesting an import token" do

        before do
          @token = @gateway.send(:get_token, 'import', 'Main Page')
        end

        it "should return a token" do
          @token.should_not == nil
          @token.should_not == "+\\"
        end

      end

    end

  end

  describe "#get" do

    describe "for an existing wiki page" do

      it "returns raw page content" do
        @gateway.get("Main Page").should == "Content"
      end

    end

    describe "for an existing empty wiki page" do

      it "returns an empty string" do
        @gateway.get("Empty").should == ""
      end

    end

    describe "for a missing wiki page" do

      it "returns nil" do
        @gateway.get("page/missing").should be_nil
      end

    end

    describe "for root (/)" do

      it "returns nil" do
        @gateway.get("").should be_nil
      end

    end

    describe "when wiki returns 503" do

      before do
        @log = Object.new
        stub(@log).debug { }
        stub(@log).warn { }
        @fail_gateway = MediaWiki::Gateway.new('http://dummy-wiki.example/w/api.php', {:maxlag => -1, :retry_delay => 0})
        stub(@fail_gateway).log { @log }
      end

      it "should retry twice and fail" do
        lambda {
          @fail_gateway.get("")
        }.should raise_error
        @log.should have_received.warn("503 Service Unavailable: Maxlag exceeded.  Retry in 0 seconds.").times(2)
      end

    end

  end

  describe "#redirect?" do

    describe "for an existing redirect page" do

      it "returns true" do
        @gateway.redirect?("Redirect").should be_true
      end

    end

    describe "for an existing non-redirect page" do

      it "returns false" do
        @gateway.redirect?("Main Page").should be_false
      end

    end

    describe "for a missing wiki page" do

      it "returns false" do
        @gateway.redirect?("page/missing").should be_false
      end

    end

  end

  describe "#render" do

    describe "for an existing wiki page" do

      before do
        @pages = @gateway.render('Main Page')
      end

      it "should return the page content" do
        expected = 'Sample <B>HTML</B> content.'
        @pages.to_s.should == expected
      end

      it "should raise an ArgumentError on illegal options" do
        lambda do
          @gateway.render("Main Page", :doesnotexist => :at_all)
        end.should raise_error(ArgumentError)
      end

      describe "with option" do

        it "should strip img tags" do
          @pages = @gateway.render('Foopage', :noimages => true)

          expected = 'Sample <B>HTML</B> content.'\
            '<span class="editsection">[<a title="Edit section: Nomenclature" href="/w/index.php?title=Seat_of_local_government&amp;action=edit&amp;section=1">edit</a>]</span>'\
            '<a title="Interpreted language" href="/wiki/Interpreted_language">interpreted language</a>'
          @pages.to_s.should == expected
        end

        it "should strip edit sections" do
          @pages = @gateway.render('Foopage', :noeditsections => true)

          expected = 'Sample <B>HTML</B> content.' \
            '<img width="150" height="150" class="thumbimage" src="http://upload.wikimedia.org/foo/Ruby_logo.svg" alt="Ruby logo.svg"/>' \
            '<a title="Interpreted language" href="/wiki/Interpreted_language">interpreted language</a>'
          @pages.to_s.should == expected
        end

        it "should make all links absolute" do
          @pages = @gateway.render('Foopage', :linkbase => "http://en.wikipedia.org")

          expected = 'Sample <B>HTML</B> content.' \
            '<img width="150" height="150" class="thumbimage" src="http://upload.wikimedia.org/foo/Ruby_logo.svg" alt="Ruby logo.svg"/>' \
            '<span class="editsection">[<a title="Edit section: Nomenclature" href="/w/index.php?title=Seat_of_local_government&amp;action=edit&amp;section=1">edit</a>]</span>'\
            '<a title="Interpreted language" href="http://en.wikipedia.org/wiki/Interpreted_language">interpreted language</a>'
          @pages.to_s.should == expected
        end

      end

    end

    describe "for a missing wiki page" do

      before do
        @pages = @gateway.render('Invalidpage')
      end

      it "should return nil" do
        @pages.should == nil
      end

    end

  end

  describe "#create" do

    before do
      @gateway.login('atlasmw', 'wombat')
    end

    describe "when creating a new page" do

      before do
        @page = @gateway.create("A New Page", "Some content")
      end

      it "should create the page" do
        expected = <<-XML
          <api>
            <edit new='' result='Success' pageid='8' title='A New Page' oldrevid='0' newrevid='8'/>
          </api>
        XML
        Hash.from_xml(@page.to_s).should == Hash.from_xml(expected)
      end

    end

    describe "when creating a page that already exists" do

      before do
        $fake_media_wiki.reset
      end

      describe "and the 'overwrite' option is set" do

        before do
          @new_page = @gateway.create("Main Page", "Some new content", :summary => "The summary", :overwrite => true)
        end

        it "should overwrite the existing page" do
          expected = <<-XML
            <api>
              <edit result='Success' pageid='8' title='Main Page' oldrevid='1' newrevid='8'/>
            </api>
          XML
          Hash.from_xml(@new_page.to_s).should == Hash.from_xml(expected)
        end

      end

      describe "and the 'overwrite' option is not set" do

        it "should raise an error" do
          lambda do
            @gateway.create("Main Page", "Some new content")
          end.should raise_error(MediaWiki::APIError)
        end

      end

    end

  end

  describe "#edit" do
    before do
      $fake_media_wiki.reset
      @edit_page = @gateway.edit("Main Page", "Some new content")
    end

    it "should overwrite the existing page" do
      expected = <<-XML
      <api>
        <edit result='Success' pageid='8' title='Main Page' oldrevid='1' newrevid='8'/>
      </api>
      XML
      Hash.from_xml(@edit_page.to_s).should == Hash.from_xml(expected)
    end

  end

  describe "#upload" do

    before do
      @gateway.login('atlasmw', 'wombat')
    end

    describe "when uploading a new file" do

      before do
        stub(File).new(anything) { "SAMPLEIMAGEDATA" }
        @page = @gateway.upload("some/path/sample_image.jpg")
      end

      it "should open the file" do
        File.should have_received.new("some/path/sample_image.jpg")
      end

      it "should upload the file" do
        expected = <<-XML
          <api>
            <upload result="Success" filename="sample_image.jpg"/>
         </api>
        XML
        Hash.from_xml(@page.to_s).should == Hash.from_xml(expected)
      end

    end

  end

  describe "#delete" do

    describe "when logged in as admin" do

      describe "and the page exists" do
        def delete_response
         <<-XML
            <api>
              <delete title='Deletable Page' reason='Default reason'/>
            </api>
         XML
        end

        before do
          @gateway.login("atlasmw", "wombat")

          create("Deletable Page", "Some content")
          @page = @gateway.delete("Deletable Page")
        end

        it "should delete the page" do
          Hash.from_xml(@page.to_s) == Hash.from_xml(delete_response)
        end
      end

      describe "and the page does not exist" do

        before do
          @gateway.login("atlasmw", "wombat")
        end

        it "should raise an error" do
          lambda do
            @gateway.delete("Missing Page")
          end.should raise_error(MediaWiki::APIError)
        end
      end
    end

    describe "when not logged in" do

      before do
        create("Deletable Page", "Some content")
      end

      it "should raise an error" do
        lambda do
          @gateway.delete("Deletable Page")
        end.should raise_error(MediaWiki::Unauthorized)
      end

    end

  end

  describe "#undelete" do

    describe "when logged in as admin" do
      before do
        $fake_media_wiki.reset
        @gateway.login("atlasmw", "wombat")
      end

      describe "and the page no longer exists" do
        before do
          @revs = @gateway.undelete("Sandbox:Undeleted")
        end

        it "should recreate the given page" do
          @gateway.list("Sandbox:Undeleted").should == [ "Sandbox:Undeleted" ]
        end

        it "should report one undeleted revision" do
          @revs.should == 1
        end
      end

      describe "but the page exists" do
        before do
          @revs = @gateway.undelete("Main Page")
        end

        it "should report zero undeleted revisions" do
          @revs.should == 0
        end
      end
    end

    describe "when not logged in" do

      it "should raise an error" do
        lambda do
          @gateway.undelete("Undeletable Page")
        end.should raise_error(MediaWiki::APIError)
      end

    end

  end

  describe "#list" do

    before do
      $fake_media_wiki.reset
    end

    describe "with an empty key" do

      before do
        @list = @gateway.list("")
      end

      it "should list all pages" do
        @list.sort.should == [ "Book:Italy", "Empty", "Foopage", "Level/Level/Index", "Main 2", "Main Page", "Redirect" ]
      end

    end

    describe "with a namespace as the key" do

      before do
        @list = @gateway.list("Book:")
      end

      it "should list all pages in the namespace" do
        @list.should == [ "Book:Italy" ]
      end

    end

    describe "with a partial title as the key" do

      before do
        @list = @gateway.list("Main")
      end

      it "should list all pages in the main namespace that start with key" do
        @list.sort.should == [ "Main 2", "Main Page" ]
      end

    end

  end

  describe "#search" do

    before do
      $fake_media_wiki.reset
      @gateway.create("Search Test", "Foo KEY Blah")
      @gateway.create("Search Test 2", "Zomp KEY Zorg")
      @gateway.create("Book:Search Test", "Bar KEY Baz")
      @gateway.create("Sandbox:Search Test", "Evil KEY Evil")
    end

    describe "with an empty key" do

      it "should raise an error" do
        lambda do
          @gateway.search("")
        end.should raise_error(MediaWiki::APIError)
      end

    end

    describe "with a valid key and no namespaces" do

      before do
        @search = @gateway.search("KEY")
      end

      it "should list all matching pages in the main namespace" do
        @search.should =~ [ "Search Test", "Search Test 2" ]
      end

    end

    describe "with a valid key and a namespace string" do

      before do
        @search = @gateway.search("KEY", "Book")
      end

      it "should list all matching pages in the specified namespaces" do
        @search.should == [ "Book:Search Test" ]
      end

    end

    describe "with a valid key and a namespace array" do

      before do
        @search = @gateway.search("KEY", ["Book", "Sandbox"])
      end

      it "should list all matching pages in the specified namespaces" do
        @search.should =~ [ "Sandbox:Search Test", "Book:Search Test" ]
      end

    end

  end

  describe "#namespaces_by_prefix" do

    before do
      $fake_media_wiki.reset
      @namespaces = @gateway.namespaces_by_prefix
    end

    it "should list all namespaces" do
      @namespaces.should == { "" => 0, "Book" => 100, "Sandbox" => 200}
    end

  end

  describe "#semantic_query" do

    before do
      @response = @gateway.semantic_query('[[place::123]]', ['mainlabel=Page'])
    end

    it "should return an HTML string" do
      @response.should == 'Sample <B>HTML</B> content.'
    end

  end

  describe "#import" do

    def import_file
      File.dirname(__FILE__) + "/import-test-data.xml"
    end

    describe "when not logged in" do

      it "should raise an error" do
        lambda do
          @gateway.import(import_file)
        end.should raise_error(MediaWiki::Unauthorized)
      end

    end

    describe "when logged in as admin" do

      def import_response
        <<-XML
          <api>
            <import>
              <page title='Main Page' ns='0' revisions='0'/>
              <page title='Template:Header' ns='10' revisions='1'/>
            </import>
          </api>
        XML
      end

      before do
        @gateway.login("atlasmw", "wombat")
        @page = @gateway.import(import_file)
      end

      it "should import content" do
        Hash.from_xml(@page.to_s) == Hash.from_xml(import_response)
      end

    end

  end

  describe "#export" do

    def export_response
      <<-XML
        <mediawiki>
          <page>
            <title>Main Page</title>
            <id>1</id>
            <revision>
              <id>1</id>
              <text>Content</text>
            </revision>
          </page>
        </mediawiki>
      XML
    end

    before do
      @page = @gateway.export("Main Page")
    end

    it "should return export data for the page" do
      Hash.from_xml(@page.to_s).should == Hash.from_xml(export_response)
    end

  end

  describe "#namespaces_by_prefix" do

    before do
      $fake_media_wiki.reset
      @namespaces = @gateway.send :namespaces_by_prefix
    end

    it "should list all namespaces" do
      @namespaces.should == { "" => 0, "Book" => 100, "Sandbox" => 200}
    end

  end

  describe "#extensions" do

    before do
      $fake_media_wiki.reset
      @extensions = @gateway.extensions
    end

    it "should list all extensions" do
      @extensions.should == { "FooExtension" => "r1", "BarExtension" => "r2" }
    end

  end

  def create(title, content, options={})
    form_data = {'action' => 'edit', 'title' => title, 'text' => content, 'summary' => (options[:summary] || ""), 'token' => @gateway.send(:get_token, 'edit', title)}
    form_data['createonly'] = "" unless options[:overwrite]
    @gateway.send(:make_api_request, form_data)
  end

  describe "#user_rights" do

    describe "when logged in as admin" do
      before do
        @gateway.login("atlasmw", "wombat")
      end

      describe "requesting a userrights token for an existing user" do

        before do
          @token = @gateway.send(:get_userrights_token, 'nonadmin')
        end

        it "should return a token" do
          @token.should_not == nil
          @token.should_not == "+\\"
        end
      end

      describe "requesting a userrights token for an nonexistant user" do

        it "should raise an error" do
          lambda do
            @gateway.send(:get_userrights_token, 'nosuchuser')
          end.should raise_error(MediaWiki::APIError)
        end
      end

      describe "changing a user's groups with a valid token" do

        def userrights_response
          <<-XML
            <api>
              <userrights user="nonadmin">
                <removed>
                  <group>oldgroup</group>
                </removed>
                <added>
                  <group>newgroup</group>
                </added>
              </userrights>
            </api>
          XML
        end

        before do
          @token = @gateway.send(:get_userrights_token, 'nonadmin')
          @result = @gateway.send(:userrights, 'nonadmin', @token, 'newgroup', 'oldgroup', 'because I can')
        end

        it "should return a result matching the input" do
          Hash.from_xml(@result.to_s).should == Hash.from_xml(userrights_response)
        end

      end

    end
  end

end
