describe_fake MediaWiki::Gateway::Pages do

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
        @log = double(:debug => nil, :warn => nil)
        @fail_gateway = MediaWiki::Gateway.new(@gateway.wiki_url, maxlag: -1, retry_delay: 0)
        allow(@fail_gateway).to receive(:log) { @log }
      end

      it "should retry until fail" do
        lambda {
          @fail_gateway.get("")
        }.should raise_error
        @log.should have_received(:warn).with("503 Service Unavailable: Maxlag exceeded.  Retry in 0 seconds.").exactly(3).times
      end

    end

    it "should pass options to RestClient::Request" do
      gateway = MediaWiki::Gateway.new(@gateway.wiki_url, {}, verify_ssl: false)
      RestClient::Request.should receive(:execute).with(hash_including(:verify_ssl => false)).and_return([double(:elements => {})])
      gateway.get("").should be_nil
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
        expect(@page.to_s).to be_equivalent_to(expected)
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
          expect(@new_page.to_s).to be_equivalent_to(expected)
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
      expect(@edit_page.to_s).to be_equivalent_to(expected)
    end

  end

  describe "#delete" do

    before do
      title, content = 'Deletable Page', 'Some content'

      @gateway.send_request(
        'action'     => 'edit',
        'title'      => title,
        'text'       => content,
        'summary'    => '',
        'createonly' => '',
        'token'      => @gateway.send(:get_token, 'edit', title)
      )
    end

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
          @page = @gateway.delete("Deletable Page")
        end

        it "should delete the page" do
          expect(@page.to_s).to be_equivalent_to(delete_response)
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

  describe "#redirect?" do

    describe "for an existing redirect page" do

      it "returns true" do
        @gateway.redirect?("Redirect").should == true
      end

    end

    describe "for an existing non-redirect page" do

      it "returns false" do
        @gateway.redirect?("Main Page").should == false
      end

    end

    describe "for a missing wiki page" do

      it "returns false" do
        @gateway.redirect?("page/missing").should == false
      end

    end

  end

end
