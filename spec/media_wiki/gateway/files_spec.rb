describe_fake MediaWiki::Gateway::Files do

  describe "#upload" do

    before do
      @gateway.login('atlasmw', 'wombat')
    end

    describe "when uploading a new file" do

      before do
        @path = 'some/path/sample_image.jpg'
        allow(File).to receive(:new).with(@path).and_return('SAMPLEIMAGEDATA')
        @page = @gateway.upload(@path)
      end

      it "should open the file" do
        File.should have_received(:new).with(@path)
      end

      it "should upload the file" do
        expected = <<-XML
          <api>
            <upload result="Success" filename="sample_image.jpg"/>
          </api>
        XML
        expect(@page.to_s).to be_equivalent_to(expected)
      end

    end

  end

end
