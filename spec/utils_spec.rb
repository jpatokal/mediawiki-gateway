require 'media_wiki'

describe MediaWiki do

  describe '.wiki_to_uri' do

    it "should underscore spaces" do
      MediaWiki.wiki_to_uri('getting there').should == 'getting_there'
    end

    it "should escape ampersands" do
      MediaWiki.wiki_to_uri('getting there & away').should == 'getting_there_%26_away'
    end

    it "should escape UTF-8" do
      MediaWiki.wiki_to_uri('Phở').should == 'Ph%E1%BB%9F'      
    end

    it "should escape each path component but leave slashes untouched" do
      MediaWiki.wiki_to_uri('Phở/B&r/B z').should == 'Ph%E1%BB%9F/B%26r/B_z'
    end

    it "should pass through nil" do
      MediaWiki.wiki_to_uri(nil).should == nil
    end
    
  end

  describe '.uri_to_wiki' do

    it "should replace underscores with spaces" do
      MediaWiki.uri_to_wiki('getting_there').should == 'getting there'
    end

    it "should unescape ampersands" do
      MediaWiki.uri_to_wiki('getting_there_%26_away').should == 'getting there & away'
    end

    it "should decode escaped UTF-8" do
      MediaWiki.uri_to_wiki('Ph%E1%BB%9F').should == 'Phở'
    end

    it "should pass through nil" do
      MediaWiki.uri_to_wiki(nil).should == nil
    end
    
  end
end
