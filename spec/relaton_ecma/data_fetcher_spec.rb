describe RelatonEcma::DataFetcher do
  let(:agent) { subject.instance_variable_get :@agent }
  let(:index) { subject.instance_variable_get :@index }

  context "initialize" do
    it "default" do
      expect(subject.instance_variable_get(:@output)).to eq "data"
      expect(subject.instance_variable_get(:@format)).to eq "yaml"
      expect(subject.instance_variable_get(:@ext)).to eq "yaml"
      expect(agent).to be_instance_of Mechanize
      expect(subject.instance_variable_get(:@files)).to eq []
      expect(index).to be_instance_of Relaton::Index::Type
    end

    it "with output & XML format" do
      df = described_class.new output: "output", format: "xml"
      expect(df.instance_variable_get(:@output)).to eq "output"
      expect(df.instance_variable_get(:@format)).to eq "xml"
      expect(df.instance_variable_get(:@ext)).to eq "xml"
    end

    it "with bibxml format" do
      df = described_class.new format: "bibxml"
      expect(df.instance_variable_get(:@format)).to eq "bibxml"
      expect(df.instance_variable_get(:@ext)).to eq "xml"
    end
  end

  it "#fetch" do
    expect(FileUtils).to receive(:mkdir_p).with("data")
    expect(subject).to receive(:html_index).with("standards")
    expect(subject).to receive(:html_index).with("technical-reports")
    expect(subject).to receive(:html_index).with("mementos")
    expect(index).to receive(:save)
    subject.fetch
  end

  context "#html_index" do
    before do
      doc = Nokogiri::HTML <<~HTML
        <html>
          <body>
            <ul>
              <li>
                <span>
                  <a href="https://www.ecma-international.org/publications/standards/Ecma-6.htm">ECMA-6</a>
                </span>
                <span>1st edition (June 1964)</span>
              </li>
            </ul>
            <div class="entry-content-wrapper">
              <div><section><div><p>2023</p></div></section></div>
              <div><section><div><p>January 2023</p></div></section></div>
              <div><section><div><p><a>Download</a></p></div></section></div>
            </div>
          </body>
        </html>
      HTML
      expect(agent).to receive(:get).with("#{described_class::URL}standards/").and_return doc
    end

    it "success" do
      expect(subject).to receive(:parse_page).twice
      subject.html_index "standards"
    end

    it "error" do
      expect(subject).to receive(:parse_page).and_raise StandardError, "error"
      expect(subject).to receive(:parse_page)
      expect { subject.html_index "standards" }.to output(/error/).to_stderr_from_any_process
    end
  end

  context "#parse_page" do
    let(:hit) { double :hit, text: "text" }

    before do
      expect(subject).to receive(:write_file).with(:item)
    end

    it "with href" do
      parser = double :parser
      expect(parser).to receive(:parse).with(no_args).and_return [:item]
      expect(RelatonEcma::DataParser).to receive(:new).with(hit).and_return parser
      subject.parse_page hit
    end
  end

  context "#write_file" do
    let(:bib) do
      docid = double :docid, id: "ECMA TR/27"
      hash = double :hash, to_yaml: :yaml
      ed = double :ed, content: "1.2"
      extent = double :extent, type: "volume", reference_from: "1"
      double :bib, docidentifier: [docid], to_hash: hash, to_bibxml: :bibxml, edition: ed, extent: [extent]
    end

    it "default output dir & YAML format" do
      expect(File).to receive(:write).with("data/ECMA_TR_27-1_2-1.yaml", :yaml, encoding: "UTF-8")
      expect(index).to receive(:add_or_update).with({ ed: "1.2", id: "ECMA TR/27", vol: "1" }, "data/ECMA_TR_27-1_2-1.yaml")
      subject.write_file bib
    end

    it "custom output dir & XML format" do
      expect(bib).to receive(:to_xml).with(bibdata: true).and_return :xml
      df = described_class.new output: "dir", format: "xml"
      expect(File).to receive(:write).with("dir/ECMA_TR_27-1_2-1.xml", :xml, encoding: "UTF-8")
      df.write_file bib
    end

    it "BibXML format" do
      df = described_class.new format: "bibxml"
      expect(File).to receive(:write).with("data/ECMA_TR_27-1_2-1.xml", :bibxml, encoding: "UTF-8")
      df.write_file bib
    end

    it "warns if file exists" do
      subject.instance_variable_set :@files, ["data/ECMA_TR_27-1_2-1.yaml"]
      expect(File).not_to receive(:write).with("data/ECMA_TR_27-1_2-1.yaml", :yaml, encoding: "UTF-8")
      expect do
        subject.write_file bib
      end.to output(/Duplicate file data\/ECMA_TR_27-1_2-1.yaml/).to_stderr_from_any_process
    end
  end
end
