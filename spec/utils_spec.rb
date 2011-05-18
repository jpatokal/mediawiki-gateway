require 'spec_helper'

describe MediaWiki do

  describe '.get_path_to_subpage' do
    it "should return the everything before the subpage if there are subpages" do
      MediaWiki.get_path_to_subpage('namespace:base/base/subpage').should == 'namespace:base/base'
    end

    it "should return nil if there is no subpage" do
      MediaWiki.get_path_to_subpage('namespace:subpage').should be_nil
    end
    
    it "should pass through nil" do
      MediaWiki.get_path_to_subpage(nil).should be_nil
    end    
  end

  describe '.get_subpage' do
    it "should return subpage name if there are subpages" do
      MediaWiki.get_subpage('namespace:base/base/subpage').should == 'subpage'
    end

    it "should return entire name if there are no subpages" do
      MediaWiki.get_subpage('namespace:subpage').should == 'namespace:subpage'
    end
    
    it "should pass through nil" do
      MediaWiki.get_subpage(nil).should be_nil
    end
  end

  describe '.get_base_name' do
    it "should return page's base name if there are subpages" do
      MediaWiki.get_base_name('namespace:root/path/subpage').should == 'namespace:root'
    end

    it "should return entire name if there are no subpages" do
      MediaWiki.get_base_name('namespace:root').should == 'namespace:root'
    end
    
    it "should pass through nil" do
      MediaWiki.get_base_name(nil).should be_nil
    end
  end

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

    it "should escape each path component but leave slashes and colons untouched" do
      MediaWiki.wiki_to_uri('Zoo:Phở/B&r/B z').should == 'Zoo:Ph%E1%BB%9F/B%26r/B_z'
    end

    it "should preserve any URL-encoded characters" do
      MediaWiki.wiki_to_uri('Zoo:Ph%E1%BB%9F/B%26r/B_z').should == 'Zoo:Ph%E1%BB%9F/B%26r/B_z'
    end

    it "should pass through nil" do
      MediaWiki.wiki_to_uri(nil).should be_nil
    end
    
  end

  describe '.uri_to_wiki' do

    it "should replace underscores with spaces" do
      MediaWiki.uri_to_wiki('getting_there').should == 'Getting there'
    end

    it "should unescape ampersands" do
      MediaWiki.uri_to_wiki('getting_there_%26_away').should == 'Getting there & away'
    end

    it "should decode escaped UTF-8" do
      MediaWiki.uri_to_wiki('Ph%E1%BB%9F').should == 'Phở'
    end

    it "should strip out illegal characters" do
      MediaWiki.uri_to_wiki('A#B<C>D[E]F|G{H}I').should == 'ABCDEFGHI'
    end

    it "should capitalize the first character, even if UTF-8" do
      MediaWiki.uri_to_wiki('óboy').should == 'Óboy'
      MediaWiki.uri_to_wiki('%C3%B3boy').should == 'Óboy'
      MediaWiki.uri_to_wiki('%E1%BB%9Fboy').should == 'Ởboy'
    end
    
    it "should pass through nil" do
      MediaWiki.uri_to_wiki(nil).should be_nil
    end
    
  end
end
