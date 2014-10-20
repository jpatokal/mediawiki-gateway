describe_fake MediaWiki::Gateway::Users do

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

  describe "#create_account" do

    describe "when logged in as admin" do
      before do
        @gateway.login("atlasmw", "wombat")
      end

      it 'should get expected result' do
        expected = <<-XML
          <api>
            <createaccount result='success' token='admin_token+\\' userid='4' username='FooBar'/>
          </api>
        XML

        expect(@gateway.create_account({ 'name' => 'FooBar', 'password' => 'BarBaz' }).to_s).to be_equivalent_to(expected)
      end

    end

  end

  describe '#options' do

    describe 'when logged in' do
      before do
        @gateway.login("atlasmw", "wombat")
      end

      describe 'requesting an options token' do
        before  do
          @token = @gateway.send(:get_options_token)
        end

        it "should return a token" do
          @token.should_not == nil
          @token.should_not == "+\\"
        end

      end

      it 'should return the expected response' do
        expected = '<api options="success" />'
        expect(@gateway.options({ :realname => 'Bar Baz' }).to_s).to be_equivalent_to(expected)
      end

    end

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
          expect(@result.to_s).to be_equivalent_to(userrights_response)
        end

      end

    end

  end

end
