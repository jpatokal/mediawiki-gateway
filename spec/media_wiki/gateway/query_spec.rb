describe_fake MediaWiki::Gateway::Query do

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

    describe "with maximum number of results" do

      before do
        @search = @gateway.search("KEY", nil, 2, 1)
      end

      it "should return at most the maximum number of results asked" do
        @search.size.should == 1
      end
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

end
