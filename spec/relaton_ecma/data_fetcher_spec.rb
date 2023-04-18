describe RelatonEcma::DataFetcher do
  let(:agent) { subject.instance_variable_get :@agent }

  context "initialize" do
    it "default" do
      expect(subject.instance_variable_get(:@output)).to eq "data"
      expect(subject.instance_variable_get(:@format)).to eq "yaml"
      expect(subject.instance_variable_get(:@ext)).to eq "yaml"
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
      expect { subject.html_index "standards" }.to output(/error/).to_stderr
    end
  end

  context "#get_page" do
    it "success" do
      expect(agent).to receive(:get).with(:url).and_return :doc
      expect(subject.get_page(:url)).to eq :doc
    end

    it "error" do
      expect(agent).to receive(:get).with(:url).and_raise StandardError, "error"
      expect(agent).to receive(:get).with(:url).and_return :doc
      expect do
        expect(subject.get_page(:url)).to eq :doc
      end.to output(/error/).to_stderr
    end
  end

  context "#parse_page" do
    let(:hit) { double :hit, text: "text" }

    before do
      expect(subject).to receive(:contributor).and_return :contributor
      expect(subject).to receive(:write_file).with(:item)
    end

    it "with href" do
      expect(hit).to receive(:[]).with(:href).and_return("href").exactly(3).times
      expect(subject).to receive(:get_page).with("href").and_return :doc
      expect(subject).to receive(:fetch_docid).with("text").and_return :docid
      expect(subject).to receive(:fetch_link).with(:doc, "href").and_return :link
      expect(subject).to receive(:fetch_title).with(:doc).and_return :title
      expect(subject).to receive(:fetch_abstract).with(:doc).and_return :abstract
      expect(subject).to receive(:fetch_date).with(:doc).and_return :date
      expect(subject).to receive(:fetch_relation).with(:doc).and_return :relation
      expect(subject).to receive(:fetch_edition).with(:doc).and_return :edition
      expect(RelatonBib::BibliographicItem).to receive(:new).with(
        type: "standard", language: ["en"], script: ["Latn"], contributor: :contributor,
        place: ["Geneva"], doctype: "document", docid: :docid, link: :link, title: :title,
        abstract: :abstract, date: :date, relation: :relation, edition: :edition
      ).and_return :item
      subject.parse_page hit
    end

    it "without href" do
      expect(hit).to receive(:[]).with(:href).and_return nil
      expect(subject).to receive(:fetch_mem_docid).with(hit).and_return :docid
      expect(subject).to receive(:fetch_link).with(hit).and_return :link
      expect(subject).to receive(:fetch_mem_title).with(hit).and_return :title
      expect(subject).to receive(:fetch_mem_date).with(hit).and_return :date
      expect(RelatonBib::BibliographicItem).to receive(:new).with(
        type: "standard", language: ["en"], script: ["Latn"],
        contributor: :contributor, place: ["Geneva"], doctype: "document",
        docid: :docid, link: :link, title: :title, date: :date
      ).and_return :item
      subject.parse_page hit
    end
  end

  it "#fetch_docid" do
    expect(RelatonBib::DocumentIdentifier).to receive(:new).with(
      type: "ECMA", id: "ECMA-6", primary: true,
    ).and_return :docid
    expect(subject.fetch_docid("ECMA-6")).to eq [:docid]
  end

  it "#fetch_mem_docid" do
    hit = double :hit
    expect(hit).to receive(:at).with("div[1]//p").and_return double(text: "2021")
    expect(subject).to receive(:fetch_docid).with("ECMA MEM/2021").and_return :docid
    expect(subject.fetch_mem_docid(hit)).to eq :docid
  end

  context "#fetch_link" do
    before do
      expect(RelatonBib::TypedUri).to receive(:new).with(type: "doi", content: "link").and_return :link
    end

    it "div/span/a" do
      doc = Nokogiri::HTML <<~HTML
        <html>
          <body>
            <div class="ecma-item-content-wrapper">
              <span><a href="link">link</a></span>
            </div>
          </body>
        </html>
      HTML
      expect(subject.fetch_link(doc)).to eq [:link]
    end

    it "div/a" do
      doc = Nokogiri::HTML <<~HTML
        <html>
          <body>
            <div class="ecma-item-content-wrapper">
              <a href="link">link</a>
            </div>
          </body>
        </html>
      HTML
      expect(subject.fetch_link(doc)).to eq [:link]
    end

    it "div/p/a" do
      doc = Nokogiri::HTML '<html><body><div><p><a href="link">link</a></p></div></body></html>'
      expect(subject.fetch_link(doc)).to eq [:link]
    end

    it "with url" do
      doc = Nokogiri::HTML '<html><body><div><p><a href="link">link</a></p></div></body></html>'
      expect(RelatonBib::TypedUri).to receive(:new).with(type: "src", content: "url").and_return :url
      expect(subject.fetch_link(doc, "url")).to eq %i[url link]
    end
  end

  it "#fetch_title" do
    doc = Nokogiri::HTML <<~HTML
      <html>
        <body>
          <div><p class="ecma-item-short-description">title</p></div>
        </body>
      </html>
    HTML
    expect(subject.fetch_title(doc)).to eq [{ content: "title", language: "en", script: "Latn" }]
  end

  it "#fetch_mem_title" do
    hit = Nokogiri::HTML("<html><body><div><p>2021</p></div><div></div></body></html>").at("/html/body")
    expect(subject.fetch_mem_title(hit)).to eq [{ content: '"Memento 2021" for year 2021', language: "en", script: "Latn" }]
  end

  it "#fetch_abstract" do
    doc = Nokogiri::HTML <<~HTML
      <html>
        <body>
          <div class="ecma-item-content"><p>Abstract 1</p></div>
          <div class="ecma-item-content"><p>abstract 2</p></div>
        </body>
      </html>
    HTML
    abstract = subject.fetch_abstract(doc)
    expect(abstract).to be_instance_of Array
    expect(abstract.first).to be_instance_of RelatonBib::FormattedString
    expect(abstract.first.content).to eq "Abstract 1\nabstract 2"
  end

  it "#fetch_date" do
    doc = Nokogiri::HTML <<~HTML
      <html>
        <body>
          <p class="ecma-item-edition">1st edition, December 2022</p>
        </body>
      </html>
    HTML
    date = subject.fetch_date doc
    expect(date).to be_instance_of Array
    expect(date.first).to be_instance_of RelatonBib::BibliographicDate
    expect(date.first.on).to eq "2022-12"
    expect(date.first.type).to eq "published"
  end

  it "#fetch_mem_date" do
    hit = Nokogiri::HTML <<~HTML
      <html>
        <body>
          <div></div>
          <div><div><p>January 2021</p></div></div>
        </body>
      </html>
    HTML
    date = subject.fetch_mem_date hit
    expect(date).to be_instance_of Array
    expect(date.first).to be_instance_of RelatonBib::BibliographicDate
    expect(date.first.on).to eq "2021-01"
    expect(date.first.type).to eq "published"
  end

  it "#fetch_relation" do
    doc = Nokogiri::HTML <<~HTML
      <html>
        <body>
          <div>
            <ul class="ecma-item-archives">
              <li>
                <span>ECMA TR/27, 1st edition, March 1985</span>
                <span><a href="https://www.ecma-international.org/wp-content/uploads/ECMA_TR-27_1st_edition_march-1985-1.pdf">Download</a></span>
              </li>
            </ul>
          </div>
        </body>
      </html>
    HTML
    relation = subject.fetch_relation doc
    expect(relation).to be_instance_of Array
    expect(relation.size).to eq 1
    expect(relation.first).to be_instance_of Hash
    expect(relation.first[:type]).to eq "updates"
    expect(relation.first[:bibitem]).to be_instance_of RelatonEcma::BibliographicItem
    expect(relation.first[:bibitem].docidentifier.first.id).to eq "ECMA TR/27"
    expect(relation.first[:bibitem].docidentifier.first.type).to eq "ECMA"
    expect(relation.first[:bibitem].docidentifier.first.primary).to be true
    expect(relation.first[:bibitem].edition.content).to eq "1"
    expect(relation.first[:bibitem].date.first.on).to eq "1985-03"
    expect(relation.first[:bibitem].date.first.type).to eq "published"
    expect(relation.first[:bibitem].link.first.type).to eq "pdf"
    expect(relation.first[:bibitem].link.first.content.to_s).to eq(
      "https://www.ecma-international.org/wp-content/uploads/ECMA_TR-27_1st_edition_march-1985-1.pdf",
    )
  end

  context "#fetch_edition" do
    shared_examples "edition" do |text, expected|
      it do
        doc = Nokogiri::HTML <<~HTML
          <html>
            <body>
              <p class="ecma-item-edition">#{text}</p>
            </body>
          </html>
        HTML
        edition = subject.fetch_edition doc
        if expected
          expect(edition).to be_instance_of RelatonBib::Edition
          expect(edition.content).to eq expected
        else
          expect(edition).to be_nil
        end
      end
    end

    it_behaves_like "edition", "1st edition, December 2022", "1"
    it_behaves_like "edition", "2nd edition, December 2022", "2"
    it_behaves_like "edition", "3rd edition, December 2022", "3"
    it_behaves_like "edition", "4th edition, December 2022", "4"
    it_behaves_like "edition", "1 edition, December 2022", nil
  end

  it "#contributor" do
    contrib = subject.contributor
    expect(contrib).to be_instance_of Array
    expect(contrib.size).to eq 1
    expect(contrib.first).to be_instance_of Hash
    expect(contrib.first[:entity]).to be_instance_of RelatonBib::Organization
    expect(contrib.first[:entity].name.first.content).to eq "Ecma International"
    expect(contrib.first[:role]).to eq [{ type: "publisher" }]
  end

  context "#write_file" do
    let(:bib) do
      docid = double :docid, id: "ECMA TR/27"
      hash = double :hash, to_yaml: :yaml
      double :bib, docidentifier: [docid], to_hash: hash, to_bibxml: :bibxml
    end

    it "default output dir & YAML format" do
      expect(File).to receive(:write).with("data/ECMA_TR_27.yaml", :yaml, encoding: "UTF-8")
      subject.write_file bib
    end

    it "custom output dir & XML format" do
      expect(bib).to receive(:to_xml).with(bibdata: true).and_return :xml
      df = described_class.new output: "dir", format: "xml"
      expect(File).to receive(:write).with("dir/ECMA_TR_27.xml", :xml, encoding: "UTF-8")
      df.write_file bib
    end

    it "BibXML format" do
      df = described_class.new format: "bibxml"
      expect(File).to receive(:write).with("data/ECMA_TR_27.xml", :bibxml, encoding: "UTF-8")
      df.write_file bib
    end

    it "warns if file exists" do
      subject.instance_variable_set :@files, ["data/ECMA_TR_27.yaml"]
      expect(File).to receive(:write).with("data/ECMA_TR_27.yaml", :yaml, encoding: "UTF-8")
      expect do
        subject.write_file bib
      end.to output(/Duplicate file data\/ECMA_TR_27.yaml/).to_stderr
    end
  end
end
