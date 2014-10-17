shared_examples 'live gateway' do

  def reset(*args, &block)
    return unless respond_to?(:live_media_wiki_reset, true)
    @gateway, @user, @pass = live_media_wiki_reset(*args, &block)
  end

  before do
    reset
  end

  it 'should match requested version' do |example|
    @gateway.version.should == example.metadata[:version]
  end

  describe '#login' do

    describe 'with a valid username & password' do

      it 'should login successfully with the default domain' do
        @gateway.login(@user, @pass).should == @user
      end

    end

    describe 'with a non-existent username' do

      it 'should raise an error' do
        lambda {
          @gateway.login(@user.swapcase, @pass)
        }.should raise_error(MediaWiki::Unauthorized)
      end

    end

    describe 'with an incorrect password' do

      it 'should raise an error' do
        lambda {
          @gateway.login(@user, @pass.swapcase)
        }.should raise_error(MediaWiki::Unauthorized)
      end

    end

  end

  describe '#get_token' do

    before do
      @blank_token = '+\\'
    end

    describe 'when not logged in' do

      describe 'requesting an edit token' do

        it 'should return a blank token' do
          token = @gateway.send(:get_token, 'edit', 'Main Page')

          token.should_not be_nil
          token.should == @blank_token
        end

      end

      describe 'requesting an import token' do

        it 'should raise an error' do
          lambda {
            @gateway.send(:get_token, 'import', 'Main Page')
          }.should raise_error(MediaWiki::APIError, /not allowed/)
        end

      end

    end

    describe 'when logged in as admin user' do

      before do
        @gateway.login(@user, @pass)
      end

      describe 'requesting an edit token for a single page' do

        it 'should return a token' do
          token = @gateway.send(:get_token, 'edit', 'Main Page')

          token.should_not be_nil
          token.should_not == @blank_token
        end

      end

      describe 'requesting an edit token for multiple pages' do

        it 'should return a token' do
          token = @gateway.send(:get_token, 'edit', 'Main Page|Another Page')

          token.should_not be_nil
          token.should_not == @blank_token
        end

      end

      describe 'requesting an import token' do

        it 'should return a token' do
          token = @gateway.send(:get_token, 'import', 'Main Page')

          token.should_not be_nil
          token.should_not == @blank_token
        end

      end

    end

  end

  describe '#get' do

    describe 'for an existing wiki page' do

      it 'returns raw page content' do
        content = @gateway.get('Main Page')
        content.should be_an_instance_of(String)
        content.should include('MediaWiki has been successfully installed.')  # XXX
      end

    end

    describe 'for an existing empty wiki page' do

      it 'returns an empty string', skip: '(page does not exist)' do
        @gateway.get('Empty').should == ''
      end

    end

    describe 'for a missing wiki page' do

      it 'returns nil' do
        @gateway.get('page/missing').should be_nil
      end

    end

    describe 'for root (/)' do

      it 'returns nil' do
        @gateway.get('').should be_nil
      end

    end

    describe 'when wiki returns 503' do

      before do
        @log = double(debug: nil, warn: nil)
        @fail_gateway = live_media_wiki_gateway(maxlag: -1, retry_delay: 0)

        allow(@fail_gateway).to receive(:log) { @log }
      end

      it 'should retry twice and fail', skip: 'expected Exception but nothing was raised' do
        lambda { @fail_gateway.get('') }.should raise_error

        @log.should have_received(:warn).with(
          '503 Service Unavailable: Maxlag exceeded.  Retry in 0 seconds.').twice
      end

    end

    it 'should pass options to RestClient::Request' do
      gateway = live_media_wiki_gateway({}, verify_ssl: false)

      RestClient::Request.should receive(:execute).with(
        hash_including(verify_ssl: false)).and_return([double(elements: {})])

      gateway.get('').should be_nil
    end

  end

  describe '#redirect?' do

    describe 'for an existing redirect page' do

      it 'returns true', skip: '(page does not exist)' do
        @gateway.redirect?('Redirect').should == true
      end

    end

    describe 'for an existing non-redirect page' do

      it 'returns false' do
        @gateway.redirect?('Main Page').should == false
      end

    end

    describe 'for a missing wiki page' do

      it 'returns false' do
        @gateway.redirect?('page/missing').should == false
      end

    end

  end

  describe '#render' do

    describe 'for an existing wiki page' do

      it 'should return the page content' do
        @gateway.render('Main Page').to_s.should include('MediaWiki has been successfully installed.')  # XXX
      end

      it 'should raise an ArgumentError on illegal options' do
        lambda {
          @gateway.render('Main Page', doesnotexist: :at_all)
        }.should raise_error(ArgumentError)
      end

      describe 'with option' do

        it 'should strip img tags', skip: '(page does not exist)' do
          page = @gateway.render('Foopage', noimages: true)

          page.to_s.should == 'Sample <B>HTML</B> content.' <<
            '<span class="editsection">[<a title="Edit section: Nomenclature" href="/w/index.php?title=Seat_of_local_government&amp;action=edit&amp;section=1">edit</a>]</span>' <<
            '<a title="Interpreted language" href="/wiki/Interpreted_language">interpreted language</a>'
        end

        it 'should strip edit sections', skip: '(page does not exist)' do
          page = @gateway.render('Foopage', noeditsections: true)

          page.to_s.should == 'Sample <B>HTML</B> content.' <<
            '<img width="150" height="150" class="thumbimage" src="http://upload.wikimedia.org/foo/Ruby_logo.svg" alt="Ruby logo.svg"/>' <<
            '<a title="Interpreted language" href="/wiki/Interpreted_language">interpreted language</a>'
        end

        it 'should make all links absolute', skip: '(page does not exist)' do
          page = @gateway.render('Foopage', linkbase: 'http://en.wikipedia.org')

          page.to_s.should == 'Sample <B>HTML</B> content.' <<
            '<img width="150" height="150" class="thumbimage" src="http://upload.wikimedia.org/foo/Ruby_logo.svg" alt="Ruby logo.svg"/>' <<
            '<span class="editsection">[<a title="Edit section: Nomenclature" href="/w/index.php?title=Seat_of_local_government&amp;action=edit&amp;section=1">edit</a>]</span>' <<
            '<a title="Interpreted language" href="http://en.wikipedia.org/wiki/Interpreted_language">interpreted language</a>'
        end

      end

    end

    describe 'for a missing wiki page' do

      it 'should return nil', skip: 'missingtitle: The page you specified doesn\'t exist' do
        @gateway.render('Invalidpage').should be_nil
      end

    end

  end

  describe '#create' do

    before do
      @gateway.login(@user, @pass)
    end

    describe 'when creating a new page' do

      it 'should create the page' do
        page = @gateway.create(title = 'A New Page', 'Some content')

        node = Nokogiri::XML::Document.parse(page.first.to_s).at('/api/edit')
        node['new'].should == ''
        node['title'].should == title
        node['result'].should == 'Success'
        node['newrevid'].to_i.should > node['oldrevid'].to_i
      end

    end

    describe 'when creating a page that already exists' do

      before do
        reset
      end

      describe 'and the `overwrite` option is set' do

        it 'should overwrite the existing page' do
          page = @gateway.create(title = 'Main Page', 'Some new content', summary: 'The summary', overwrite: true)

          node = Nokogiri::XML::Document.parse(page.first.to_s).at('/api/edit')
          node['new'].should be_nil
          node['title'].should == title
          node['result'].should == 'Success'
          node['newrevid'].to_i.should > node['oldrevid'].to_i
        end

      end

      describe 'and the `overwrite` option is not set' do

        it 'should raise an error' do
          lambda {
            @gateway.create('Main Page', 'Some new content')
          }.should raise_error(MediaWiki::APIError)
        end

      end

    end

  end

  describe '#edit' do

    it 'should overwrite the existing page', skip: '(result differs)' do
      reset

      page = @gateway.edit('Main Page', 'Some new content')

      expect(page.first.to_s).to be_equivalent_to(<<-EOT)
        <api>
          <edit result="Success" pageid="8" title="Main Page" oldrevid="1" newrevid="8"/>
        </api>
      EOT
    end

  end

  describe '#upload' do

    before do
      @gateway.login(@user, @pass)
    end

    describe 'when uploading a new file', skip: 'badupload_file: File upload param file is not a file upload' do

      before do
        @path = 'some/path/sample_image.jpg'
        allow(File).to receive(:new).with(@path).and_return('SAMPLEIMAGEDATA')

        @page = @gateway.upload(@path)
      end

      it 'should open the file' do
        File.should have_received(:new).with(@path)
      end

      it 'should upload the file' do
        expect(@page.first.to_s).to be_equivalent_to(<<-EOT)
          <api>
            <upload result="Success" filename="sample_image.jpg"/>
          </api>
        EOT
      end

    end

  end

  describe '#delete' do

    def delete_page
      title, content = 'Deletable Page', 'Some content'

      @gateway.send(:make_api_request,
        'action'     => 'edit',
        'title'      => title,
        'text'       => content,
        'summary'    => '',
        'createonly' => '',
        'token'      => @gateway.send(:get_token, 'edit', title)
      )

      yield lambda { @gateway.delete(title) }
    end

    describe 'when logged in as admin' do

      describe 'and the page exists' do

        it 'should delete the page', skip: '(result differs)' do
          @gateway.login(@user, @pass)

          delete_page { |block|
            expect(block.call.first.to_s).to be_equivalent_to(<<-EOT)
              <api>
                <delete title="Deletable Page" reason="Default reason"/>
              </api>
            EOT
          }
        end

      end

      describe 'and the page does not exist' do

        before do
          @gateway.login(@user, @pass)
        end

        it 'should raise an error' do
          lambda {
            @gateway.delete('Missing Page')
          }.should raise_error(MediaWiki::APIError)
        end

      end

    end

    describe 'when not logged in' do

      it 'should raise an error' do
        delete_page { |block| block.should raise_error(MediaWiki::APIError) }
      end

    end

  end

  describe '#undelete' do

    describe 'when logged in as admin' do

      before do
        reset
        @gateway.login(@user, @pass)
      end

      describe 'and the page no longer exists', skip: '(page does not exist)' do

        before do
          @revs = @gateway.undelete('Sandbox:Undeleted')
        end

        it 'should recreate the given page' do
          @gateway.list('Sandbox:Undeleted').should == ['Sandbox:Undeleted']
        end

        it 'should report one undeleted revision' do
          @revs.should == 1
        end
      end

      describe 'but the page exists' do

        before do
          @revs = @gateway.undelete('Main Page')
        end

        it 'should report zero undeleted revisions' do
          @revs.should == 0
        end

      end

    end

    describe 'when not logged in' do

      it 'should raise an error' do
        lambda {
          @gateway.undelete('Undeletable Page')
        }.should raise_error(MediaWiki::APIError)
      end

    end

  end

  describe '#list', skip: '(pages do not exist)' do

    before do
      reset
    end

    describe 'with an empty key' do

      it 'should list all pages' do
        @gateway.list('').sort.should == ['Book:Italy', 'Empty', 'Foopage', 'Level/Level/Index', 'Main 2', 'Main Page', 'Redirect']
      end

    end

    describe 'with a namespace as the key' do

      it 'should list all pages in the namespace' do
        @gateway.list('Book:').should == ['Book:Italy']
      end

    end

    describe 'with a partial title as the key' do

      it 'should list all pages in the main namespace that start with key' do
        @gateway.list('Main').sort.should == ['Main 2', 'Main Page']
      end

    end

  end

  describe '#search' do

    before :all do
      reset { |gateway|
        gateway.create('Search Test', 'Foo KEY Blah')
        gateway.create('Search Test 2', 'Zomp KEY Zorg')
        gateway.create('Book:Search Test', 'Bar KEY Baz')
        gateway.create('Sandbox:Search Test', 'Evil KEY Evil')
      }
    end

    before do
      # warning: srlimit may not be over 50 (set to 500) for users
      @gateway = live_media_wiki_gateway(limit: 50)
    end

    describe 'with an empty key' do

      it 'should raise an error' do
        lambda {
          @gateway.search('')
        }.should raise_error(MediaWiki::APIError)
      end

    end

    describe 'with a valid key and no namespaces', skip: '(searches all namespaces)' do

      it 'should list all matching pages in the main namespace' do
        @gateway.search('KEY').should =~ ['Search Test', 'Search Test 2']
      end

    end

    describe 'with a valid key and a namespace string', skip: '(searches all namespaces)' do

      it 'should list all matching pages in the specified namespaces' do
        @gateway.search('KEY', 'Book').should == ['Book:Search Test']
      end

    end

    describe 'with a valid key and a namespace array', skip: 'warning: Unrecognized values for parameter \'srnamespace\'' do

      it 'should list all matching pages in the specified namespaces' do
        @gateway.search('KEY', ['Book', 'Sandbox']).should =~ ['Sandbox:Search Test', 'Book:Search Test']
      end

    end

    describe 'with maximum number of results' do

      it 'should return at most the maximum number of results asked', skip: 'undefined method `to_i\' for sroffset=\'1\':REXML::Attribute' do
        @gateway.search('KEY', nil, 2, 1).size.should == 1
      end

    end

  end

  describe '#namespaces_by_prefix' do

    it 'should list all namespaces', skip: '(actual namespaces differ)' do
      reset
      @gateway.namespaces_by_prefix.should == { '' => 0, 'Book' => 100, 'Sandbox' => 200 }
    end

  end

  describe '#semantic_query', skip: 'Semantic MediaWiki extension not installed' do

    it 'should return an HTML string' do
      response = @gateway.semantic_query('[[place::123]]', ['mainlabel=Page'])
      response.should include('MediaWiki has been successfully installed.')  # XXX
    end

  end

  describe '#import' do

    before do
      @import_file = File.dirname(__FILE__) + '/../import-test-data.xml'
    end

    describe 'when not logged in' do

      it 'should raise an error' do
        lambda {
          @gateway.import(@import_file)
        }.should raise_error(MediaWiki::APIError)
      end

    end

    describe 'when logged in as admin' do

      it 'should import content' do
        @gateway.login(@user, @pass)

        page = @gateway.import(@import_file)

        expect(page.first.to_s).to be_equivalent_to(<<-EOT)
          <api>
            <import>
              <page title="Main Page" ns="0" revisions="1"/>
              <page title="Template:Header" ns="10" revisions="1"/>
            </import>
          </api>
        EOT
      end

    end

  end

  describe '#export' do

    it 'should return export data for the page' do
      page = @gateway.export(title = 'Main Page')

      node = Nokogiri::XML::Document.parse(page.to_s).at('/xmlns:mediawiki/xmlns:page')
      node.at('./xmlns:id').text.should_not be_nil
      node.at('./xmlns:title').text.should == title
      node.at('./xmlns:revision').text.should_not be_nil
    end

  end

  describe '#extensions' do

    it 'should list all extensions', skip: '(extensions are not installed)' do
      reset
      @gateway.extensions.should == { 'FooExtension' => 'r1', 'BarExtension' => 'r2', 'Semantic MediaWiki' => '1.5' }
    end

  end

  describe '#create_account' do

    describe 'when logged in as admin' do

      before do
        @gateway.login(@user, @pass)
      end

      it 'should get expected result' do
        page = @gateway.create_account('name' => name = 'FooBar', 'password' => 'BarBaz')

        node = Nokogiri::XML::Document.parse(page.to_s).at('/api/createaccount')
        node['token'].should_not be_nil
        node['userid'].should_not be_nil
        node['result'].should == 'Success'
        node['username'].should == name
      end

    end

  end

  describe '#options' do

    describe 'when logged in' do

      before do
        @gateway.login(@user, @pass)
      end

      describe 'requesting an options token' do

        it 'should return a token' do
          token = @gateway.send(:get_options_token)

          token.should_not be_nil
          token.should_not == '+\\'
        end

      end

      it 'should return the expected response', skip: 'warning: Validation error for \'realname\': cannot be set by this module' do
        expect(@gateway.options(realname: 'Bar Baz').to_s).to be_equivalent_to('<api options="success" />')
      end

    end

  end

  describe '#user_rights' do

    describe 'when logged in as admin' do

      before do
        @gateway.login(@user, @pass)
      end

      describe 'requesting a userrights token for an existing user' do

        it 'should return a token', skip: '(user does not exist)' do
          token = @gateway.send(:get_userrights_token, 'nonadmin')

          token.should_not be_nil
          token.should_not == '+\\'
        end
      end

      describe 'requesting a userrights token for an nonexistant user' do

        it 'should raise an error' do
          lambda {
            @gateway.send(:get_userrights_token, 'nosuchuser')
          }.should raise_error(MediaWiki::APIError)
        end
      end

      describe "changing a user's groups with a valid token" do

        it 'should return a result matching the input', skip: '(user does not exist)' do
          token  = @gateway.send(:get_userrights_token, 'nonadmin')
          result = @gateway.send(:userrights, 'nonadmin', token, 'newgroup', 'oldgroup', 'because I can')

          expect(@result.to_s).to be_equivalent_to(<<-EOT)
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
          EOT
        end

      end

    end

  end

end

unless (pool_size = Integer(ENV['LIVE_POOL_SIZE'] || 2)) > 1
  warn 'Docker pool size must be greater than 1.'
else
  ENV.fetch('LIVE_VERSION', '1.23.4').split(/[\s:,]/).each { |version|
    describe_live(MediaWiki::Gateway, version: version, pool_size: pool_size) {
      include_examples 'live gateway'
    }
  }
end
