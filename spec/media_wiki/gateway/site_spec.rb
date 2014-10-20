describe_fake MediaWiki::Gateway::Site do

  describe "#import" do

    let(:import_file) { data('import.xml') }

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
        expect(@page.to_s).to be_equivalent_to(import_response)
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
      expect(@page.to_s).to be_equivalent_to(export_response)
    end

  end

  describe "#siteinfo" do

    before do
      $fake_media_wiki.reset
      @siteinfo = @gateway.siteinfo
    end

    it "should get the siteinfo" do
      @siteinfo.should == { 'generator' => "MediaWiki #{MediaWiki::VERSION}" }
    end

  end

  describe "#version" do

    before do
      $fake_media_wiki.reset
      @version = @gateway.version
    end

    it "should get the version" do
      @version.should == MediaWiki::VERSION
    end

  end

  describe "#namespaces_by_prefix" do

    before do
      $fake_media_wiki.reset
      @namespaces = @gateway.namespaces_by_prefix
    end

    it "should list all namespaces" do
      @namespaces.should == { "" => 0, "Book" => 100, "Sandbox" => 200 }
    end

  end

  describe "#extensions" do

    before do
      $fake_media_wiki.reset
      @extensions = @gateway.extensions
    end

    it "should list all extensions" do
      @extensions.should == { "FooExtension" => "r1", "BarExtension" => "r2", 'Semantic MediaWiki' => '1.5' }
    end

  end

end
