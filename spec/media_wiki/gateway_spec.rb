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

end
