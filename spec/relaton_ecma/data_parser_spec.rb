describe RelatonEcma::DataParser do
  let(:hit) { double(:hit) }
  subject { described_class.new(hit) }

  it "#contributor" do
    contrib = subject.contributor

    expect(contrib).to be_instance_of Array
    expect(contrib.size).to eq 1
    expect(contrib.first).to be_instance_of Hash
    expect(contrib.first[:entity]).to be_instance_of RelatonBib::Organization
    expect(contrib.first[:entity].name.first.content).to eq "Ecma International"
    expect(contrib.first[:role]).to eq [{ type: "publisher" }]
  end

  context "#parse" do
    before do
      expect(subject).to receive(:contributor).and_return :contributor
    end

    it "with href" do
      expect(hit).to receive(:[]).with(:href).and_return("href").twice
      expect(subject).to receive(:get_page).with("href").and_return :doc
      expect(subject).to receive(:fetch_docid).with(no_args).and_return :docid
      expect(subject).to receive(:fetch_title).and_return :title
      expect(subject).to receive(:fetch_abstract).and_return :abstract
      expect(subject).to receive(:fetch_date).and_return :date
      expect(subject).to receive(:fetch_link).and_return :link
      expect(subject).to receive(:fetch_relation).and_return :relation
      expect(subject).to receive(:fetch_edition).and_return :edition
      expect(subject).to receive(:parse_editions).and_return []
      expect(subject).to receive(:fetch_doctype).and_return(:doctype).twice
      expect(RelatonEcma::BibliographicItem).to receive(:new).with(
        type: "standard", language: ["en"], script: ["Latn"], contributor: :contributor,
        place: ["Geneva"], doctype: :doctype, docid: :docid, link: :link, title: :title,
        abstract: :abstract, date: :date, relation: :relation, edition: :edition
      ).and_return :item

      subject.parse

      expect(subject.instance_variable_get(:@doc)).to eq :doc
    end

    it "without href" do
      expect(hit).to receive(:[]).with(:href).and_return nil
      expect(subject).to receive(:fetch_mem_docid).and_return :docid
      expect(subject).to receive(:fetch_mem_title).and_return :title
      expect(subject).to receive(:fetch_mem_date).and_return :date
      expect(subject).to receive(:fetch_mem_link).and_return :link
      expect(subject).to receive(:fetch_mem_doctype).and_return :doctype
      expect(RelatonEcma::BibliographicItem).to receive(:new).with(
        type: "standard", language: ["en"], script: ["Latn"],
        contributor: :contributor, place: ["Geneva"], doctype: :doctype,
        docid: :docid, link: :link, title: :title, date: :date
      ).and_return :item

      subject.parse
    end
  end

  context "#get_page" do
    let(:agent) { subject.instance_variable_get :@agent }

    it "success" do
      expect(agent).to receive(:get).with(:url).and_return :doc

      expect(subject.get_page(:url)).to eq :doc
    end

    it "error" do
      expect(agent).to receive(:get).with(:url).and_raise StandardError, "error"
      expect(agent).to receive(:get).with(:url).and_return :doc

      expect do
        expect(subject.get_page(:url)).to eq :doc
      end.to output(/error/).to_stderr_from_any_process
    end
  end

  it "#fetch_docid" do
    expect(RelatonBib::DocumentIdentifier).to receive(:new).with(
      type: "ECMA", id: "ECMA-6", primary: true,
    ).and_return :docid

    expect(subject.fetch_docid("ECMA-6")).to eq [:docid]
  end

  context "#fetch_link" do
    before do
      expect(subject).to receive(:edition_translation_link).with(nil).and_return [:translation]
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
      subject.instance_variable_set :@doc, doc

      expect(RelatonBib::TypedUri).to receive(:new).with(type: "pdf", content: "link").and_return :link
      expect(hit).to receive(:[]).with(:href).and_return nil

      expect(subject.fetch_link).to eq %i[link translation]
    end

    it "with url" do
      doc = Nokogiri::HTML "<html><body></body></html>"
      subject.instance_variable_set :@doc, doc

      expect(hit).to receive(:[]).with(:href).and_return("url").twice
      expect(RelatonBib::TypedUri).to receive(:new).with(type: "src", content: "url").and_return :url

      expect(subject.fetch_link).to eq %i[url translation]
    end
  end

  context "#transltion_link" do
    it "Japanese" do
      doc = Nokogiri::HTML <<~HTML
        <html>
          <body>
            <main>
              <article>
                <div>
                  <div>
                    <standard>
                      <div></div>
                      <div>
                        <ul>
                          <li>
                            <span>ECMA-370, Japanese version, 3rd edition</span>
                            <span>
                              <a href="https://www.ecma-international.org/wp-content/uploads/ECMA-370_3rd_edition_december_2008_japanese.pdf">Download</a>
                            </span>
                          </li>
                        </ul>
                      </div>
                    </standard>
                  </div>
                </div>
              </article>
            </main>
          </body>
        </html>
      HTML
      subject.instance_variable_set :@doc, doc

      link = subject.translation_link

      expect(link).to be_instance_of Array
      expect(link.first).to be_instance_of Hash
      expect(link.first[:ed]).to eq "3"
      expect(link.first[:link]).to be_instance_of RelatonBib::TypedUri
      expect(link.first[:link].type).to eq "pdf"
      expect(link.first[:link].content).to be_instance_of Addressable::URI
      expect(link.first[:link].content.to_s).to eq "https://www.ecma-international.org/wp-content/uploads/ECMA-370_3rd_edition_december_2008_japanese.pdf"
      expect(link.first[:link].language).to eq "ja"
      expect(link.first[:link].script).to eq "Jpan"
    end
  end

  it "#fetch_mem_link" do
    doc = Nokogiri::HTML <<~HTML
      <html>
        <body>
          <div>
            <div class="entry-content-wrapper">
              <div>
                <section>
                  <div>
                    <p>
                      <a href="https://www.ecma-international.org/wp-content/uploads/Ecma-memento-2023-public.pdf">Download</a>
                    </p>
                  </div>
                </section>
              </div>
            </div>
          </div>
        </body>
      </html>
    HTML
    hit = doc.at("//div[contains(@class, 'entry-content-wrapper')][.//a[.='Download']]")
    subject.instance_variable_set :@hit, hit

    link = subject.fetch_mem_link

    expect(link).to be_instance_of Array
    expect(link.size).to eq 1
    expect(link.first).to be_instance_of RelatonBib::TypedUri
    expect(link.first.type).to eq "pdf"
    expect(link.first.content.to_s).to eq "https://www.ecma-international.org/wp-content/uploads/Ecma-memento-2023-public.pdf"
  end

  it "#edition_translation_link" do
    expect(subject).to receive(:translation_link).and_return [{ ed: "3", link: :link1 }, { ed: "4", link: :link2 }]

    trlink = subject.edition_translation_link "4"

    expect(trlink).to eq [:link2]
  end

  it "#fetch_title" do
    doc = Nokogiri::HTML <<~HTML
      <html>
        <body>
          <div><p class="ecma-item-short-description">title</p></div>
        </body>
      </html>
    HTML
    subject.instance_variable_set :@doc, doc

    expect(subject.fetch_title).to eq [{ content: "title", language: "en", script: "Latn" }]
  end

  it "#fetch_mem_title" do
    hit = Nokogiri::HTML("<html><body><div><p>2021</p></div><div></div></body></html>").at("/html/body")
    subject.instance_variable_set :@hit, hit

    expect(subject.fetch_mem_title).to eq [{ content: '"Memento 2021" for year 2021', language: "en", script: "Latn" }]
  end

  it "#fetch_mem_docid" do
    hit = double :hit
    expect(hit).to receive(:at).with("div[1]//p").and_return double(text: "2021")
    subject.instance_variable_set :@hit, hit
    expect(subject).to receive(:fetch_docid).with("ECMA MEM/2021").and_return :docid

    expect(subject.fetch_mem_docid).to eq :docid
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
    subject.instance_variable_set :@doc, doc

    abstract = subject.fetch_abstract

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
    subject.instance_variable_set :@doc, doc

    date = subject.fetch_date

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
    subject.instance_variable_set :@hit, hit

    date = subject.fetch_mem_date

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
    subject.instance_variable_set :@doc, doc

    relation = subject.fetch_relation

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

  it "#parse_editions" do
    doc = Nokogiri::HTML <<~HTML
      <html>
        <body>
          <div id="main">
            <div>
              <div>
                <main>
                  <article>
                    <div>
                      <div>
                        <standard>
                          <div></div>
                          <div></div>
                          <div>
                            <ul>
                              <li>
                                <a href="https://262.ecma-international.org/5.1/index.html">ECMA-262 5.1 edition, June 2011</a>
                              </li>
                            </ul>
                          </div>
                        </standard>
                      </div>
                    </div>
                  </article>
                </main>
              </div>
            </div>
          </div>
        </body>
      </html>
    HTML
    subject.instance_variable_set :@doc, doc
    expect(subject).to receive(:edition_translation_link).with("5.1").and_return [:translation]

    expect(RelatonEcma::BibliographicItem).to receive(:new) do |args|
      expect(args[:link]).to be_instance_of Array
      expect(args[:link].size).to eq 2
      expect(args[:link].first).to be_instance_of RelatonBib::TypedUri
      expect(args[:link].first.type).to eq "src"
      expect(args[:link].first.content.to_s).to eq "https://262.ecma-international.org/5.1/index.html"
      expect(args[:link].last).to eq :translation
      expect(args[:edition]).to be_instance_of RelatonBib::Edition
      expect(args[:edition].content).to eq "5.1"
      expect(args[:date]).to be_instance_of Array
      expect(args[:date].size).to eq 1
      expect(args[:date].first).to be_instance_of RelatonBib::BibliographicDate
      expect(args[:date].first.on).to eq "2011-06"
      expect(args[:date].first.type).to eq "published"
      :item
    end

    expect(subject.parse_editions).to eq [:item]
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
        subject.instance_variable_set :@doc, doc

        edition = subject.fetch_edition

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

  context "#edition_id_parts" do
    shared_examples "edition id parts" do |text, docid, edition, date, volume|
      it do
        id, ed, dt, vol = subject.edition_id_parts(text)

        expect(id).to eq docid
        expect(ed).to eq edition
        expect(vol).to eq volume
        expect(dt).to be_instance_of Array
        if date
          expect(dt.size).to eq 1
          expect(dt.first).to be_instance_of RelatonBib::BibliographicDate
          expect(dt.first.on).to eq date
          expect(dt.first.type).to eq "published"
        else
          expect(dt).to be_empty
        end
      end
    end

    it_behaves_like "edition id parts", "ECMA-402 1st edition, December 2012", "ECMA-402", "1", "2012-12", nil
    it_behaves_like "edition id parts", "ECMA-402, 2nd edition, May 2011", "ECMA-402", "2", "2011-05", nil
    it_behaves_like "edition id parts", "ECMA-402 3rd edition, December 2012", "ECMA-402", "3", "2012-12", nil
    it_behaves_like "edition id parts", "ECMA-402 4th edition, December 2012", "ECMA-402", "4", "2012-12", nil
    it_behaves_like "edition id parts", "ECMA-410, 2nd edition. June 2015", "ECMA-410", "2", "2015-06", nil
    it_behaves_like "edition id parts", "ECMA-269, 1st edition", "ECMA-269", "1", nil, nil
    it_behaves_like "edition id parts", "ECMA-269, Volume 1, 3rd edition, December 1998", "ECMA-269", "3", "1998-12", "1"
    it_behaves_like "edition id parts", "ECMA-269, 9th edition, December 2011, changes since the previous edition", "ECMA-269", "9", "2011-12", nil
  end

  context "#edition_link" do
    it "pdf" do
      doc = Nokogiri::HTML <<~HTML
        <html>
          <body>
            <div id="main">
              <ul>
                <li>
                  <span>
                    <a href="https://www.ecma-international.org/wp-content/uploads/ECMA-254_1st_edition_december_1996.pdf">Download</a>
                  </span>
                </li>
              </ul>
            </div>
          </body>
        </html>
      HTML

      link = subject.edition_link doc.at("//ul/li")

      expect(link).to be_instance_of Array
      expect(link.size).to eq 1
      expect(link.first).to be_instance_of RelatonBib::TypedUri
      expect(link.first.type).to eq "pdf"
      expect(link.first.content.to_s).to eq "https://www.ecma-international.org/wp-content/uploads/ECMA-254_1st_edition_december_1996.pdf"
    end
  end

  it "#fetch_doctype" do
    doctype = subject.fetch_doctype
    expect(doctype).to be_instance_of RelatonBib::DocumentType
    expect(doctype.type).to eq "document"
  end
end
