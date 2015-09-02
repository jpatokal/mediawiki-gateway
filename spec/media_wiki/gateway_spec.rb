describe_fake MediaWiki::Gateway do

  describe 'setting the User-Agent header' do

    ua = described_class::USER_AGENT

    def expect_user_agent(expected, actual = default = true)
      options = default ? {} : { user_agent: actual }
      gateway = described_class.new('test.wiki', options)
      expect(gateway.headers['User-Agent']).to eq(expected)
    end

    it 'should default to generic value' do
      expect_user_agent ua
    end

    it 'should ignore nil value' do
      expect_user_agent ua, nil
    end

    it 'should prepend given value' do
      expect_user_agent "Foo/4.2 #{ua}", 'Foo/4.2'
    end

    describe 'with global default' do

      before do
        described_class.default_user_agent = 'Bar/2.3'
      end

      after do
        described_class.default_user_agent = nil
      end

      it 'should default to global value' do
        expect_user_agent "Bar/2.3 #{ua}"
      end

      it 'should accept nil value' do
        expect_user_agent ua, nil
      end

      it 'should override with given value' do
        expect_user_agent "Foo/4.2 #{ua}", 'Foo/4.2'
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

  describe 'receiving a maxlag error' do

    let(:maxlag) { 15 }

    before do
      @log = double(:debug => nil, :warn => nil)
      @maxlag_gateway = MediaWiki::Gateway.new(@gateway.wiki_url, maxlag: -maxlag, retry_delay: 0)
      allow(@maxlag_gateway).to receive(:log) { @log }
      allow(@maxlag_gateway).to receive(:sleep)
    end

    describe 'in HTTP 200, XML format' do

      it 'should retry until retries are exceeded' do
        lambda do
          @maxlag_gateway.send_request({ 'maxlag_code' => 200 })
        end.should raise_error(/Retries exceeded/)
        @log.should have_received(:warn).with(/maxlag exceeded/).exactly(3).times
      end

      it 'should parse the maxlag from the error message' do
        expect(@maxlag_gateway).to receive(:sleep).with(maxlag).exactly(3).times

        lambda do
          @maxlag_gateway.send_request({ 'maxlag_code' => 200 })
        end.should raise_error(/Retries exceeded/)
        @log.should have_received(:warn).with(/maxlag exceeded/).exactly(3).times
      end

    end

    describe 'in HTTP 503, plain format' do

      it 'should retry until retries are exceeded' do
        lambda do
          @maxlag_gateway.send_request({ 'maxlag_code' => 503 })
        end.should raise_error(/Retries exceeded/)

        @log.should have_received(:warn).with("503 Service Unavailable: Maxlag exceeded.  Retry in 0 seconds.").exactly(3).times
      end

    end

  end

end
