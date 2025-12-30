require "relaton/ecma/data_fetcher"

describe Relaton::Ecma::DataFetcher do
  subject { described_class.new("data", "yaml") }

  it "#fetch" do
    expect(subject).to receive(:html_index).with("standards")
    expect(subject).to receive(:html_index).with("technical-reports")
    expect(subject).to receive(:html_index).with("mementos")
    expect(subject.index).to receive(:save)
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
      expect(subject.agent).to receive(:get).with("#{described_class::URL}standards/").and_return doc
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
      expect(Relaton::Ecma::DataParser).to receive(:new).with(hit).and_return parser
      subject.parse_page hit
    end
  end

  context "#write_file" do
    let(:bib) do
      docid = Relaton::Bib::Docidentifier.new content: "ECMA TR/27"
      ed = Relaton::Bib::Edition.new content: "1.2"
      locality = Relaton::Bib::Locality.new type: "volume", reference_from: "1"
      extent = Relaton::Bib::Extent.new locality: [locality]
      Relaton::Ecma::ItemData.new docidentifier: [docid], edition: ed, extent: [extent]
    end

    it "default output dir & YAML format" do
      expect(File).to receive(:write).with("data/ECMA_TR_27-1_2-1.yaml", match(/ECMA TR\/27/), encoding: "UTF-8")
      expect(subject.index).to receive(:add_or_update)
        .with({ ed: "1.2", id: "ECMA TR/27", vol: "1" }, "data/ECMA_TR_27-1_2-1.yaml")
      subject.write_file bib
    end

    it "custom output dir & XML format" do
      expect(bib).to receive(:to_xml).with(bibdata: true).and_return :xml
      df = described_class.new "dir", "xml"
      expect(File).to receive(:write).with("dir/ECMA_TR_27-1_2-1.xml", :xml, encoding: "UTF-8")
      df.write_file bib
    end

    xit "BibXML format" do
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
