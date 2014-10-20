describe_fake MediaWiki::Gateway do

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
