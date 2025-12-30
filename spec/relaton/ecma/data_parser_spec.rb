require "relaton/ecma/data_fetcher"

describe Relaton::Ecma::DataParser do
  let(:hit) do
    Nokogiri::HTML(
      '<a href="https://ecma-international.org/publications-and-standards/standards/ecma-370/">ECMA-370</a>'
    ).at("a")
  end
  let(:hit_mem) do
    Nokogiri::HTML(<<~HTML).at("div")
      <div class="entry-content-wrapper clearfix">
        <div><section><div><p>2025</p></div></section></div>
        <div><section><div><p>January 2025</p></div></section></div>
        <div><section><div><p>
          <a href="https://ecma-international.org/wp-content/uploads/Ecma-memento-2025-public.pdf">Download</a>
        </p></div></section></div>
      </div>
    HTML
  end
  let(:translations) do
    Nokogiri::HTML <<~HTML
      <html>
        <body>
          <div class="ecma-item-archives-wrapper">
            <h2>Translations</h2>
            <ul class="ecma-item-archives">
              <li>
                <span>ECMA-370, Japanese version, 1st edition</span>
                <span>
                  <a href="https://ecma-international.org/wp-content/uploads/ECMA-370_1st_edition_japanese_version.pdf">Download</a>
                </span>
              </li>
              <li>
                <span>ECMA-370, Japanese version, 2nd edition</span>
                <span>
                  <a href="https://ecma-international.org/wp-content/uploads/ECMA-370_2nd_edition_december_2006_japanese.pdf">Download</a>
                </span>
              </li>
              <li>
                <span>ECMA-370, Japanese version, 3rd edition</span>
                <span>
                  <a href="https://ecma-international.org/wp-content/uploads/ECMA-370_3rd_edition_december_2008_japanese.pdf">Download</a>
                </span>
              </li>
            </ul>
          </div>
        </body>
      </html>
    HTML
  end

  subject { described_class.new(hit) }

  it "#contributor" do
    contrib = subject.contributor

    expect(contrib).to be_instance_of Array
    expect(contrib.size).to eq 1
    expect(contrib.first).to be_instance_of Relaton::Bib::Contributor
    expect(contrib.first.organization).to be_instance_of Relaton::Bib::Organization
    expect(contrib.first.organization.name.first.content).to eq "Ecma International"
    expect(contrib.first.role.first.type).to eq "publisher"
  end

  context "#parse" do
    context "with hit[:href]" do

      it "returns standards", vcr: "ecma_370" do
        items = subject.parse
        expect(items).to be_instance_of Array
        expect(items.size).to eq 7
        expect(items.first).to be_instance_of Relaton::Ecma::ItemData
        expect(items.first.type).to eq "standard"
        expect(items.first.language).to eq ["en"]
        expect(items.first.script).to eq ["Latn"]
        expect(items.first.place.first).to be_instance_of Relaton::Bib::Place
        expect(items.first.docidentifier.first).to be_instance_of Relaton::Bib::Docidentifier
        expect(items.first.title.first).to be_instance_of Relaton::Bib::Title
        expect(items.first.abstract.first).to be_instance_of Relaton::Bib::LocalizedMarkedUpString
        expect(items.first.date.first).to be_instance_of Relaton::Bib::Date
        expect(items.first.source.first).to be_instance_of Relaton::Bib::Uri
        expect(items.first.relation.first).to be_instance_of Relaton::Bib::Relation
        expect(items.first.edition).to be_instance_of Relaton::Bib::Edition
        expect(items.first.ext).to be_instance_of Relaton::Ecma::Ext
        expect(items.first.ext.doctype).to be_instance_of Relaton::Bib::Doctype
        expect(items.first.ext.flavor).to eq "ecma"
      end
    end

    context "without hit[:href]" do
      let(:hit) { hit_mem }

      it "returns memento" do
        items = subject.parse
        expect(items).to be_instance_of Array
        expect(items.size).to eq 1
        expect(items.first).to be_instance_of Relaton::Ecma::ItemData
        expect(items.first.docidentifier.first).to be_instance_of Relaton::Bib::Docidentifier
        expect(items.first.title.first).to be_instance_of Relaton::Bib::Title
        expect(items.first.date.first).to be_instance_of Relaton::Bib::Date
        expect(items.first.source.first).to be_instance_of Relaton::Bib::Uri
        expect(items.first.ext).to be_instance_of Relaton::Ecma::Ext
        expect(items.first.ext.doctype).to be_instance_of Relaton::Bib::Doctype
        expect(items.first.ext.flavor).to eq "ecma"
      end
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

  it "#fetch_docidentifier" do
    docid = subject.fetch_docidentifier("ECMA-6")
    expect(docid.first).to be_instance_of Relaton::Bib::Docidentifier
    expect(docid.first.type).to eq "ECMA"
    expect(docid.first.content).to eq "ECMA-6"
  end

  context "#fetch_source" do
    before do
      expect(subject).to receive(:edition_translation_source).with(nil).and_return [:translation]
    end

    context "without hit[:href]" do
      let(:hit) { hit_mem }
      let(:doc) do
        Nokogiri::HTML <<~HTML
          <html>
            <body>
              <div class="ecma-item-content-wrapper">
                <span><a href="link">link</a></span>
              </div>
            </body>
          </html>
        HTML
      end

      it "returns source from span/a" do
        subject.instance_variable_set :@doc, doc
        source, translation = subject.fetch_source
        expect(source).to be_instance_of Relaton::Bib::Uri
        expect(source.type).to eq "pdf"
        expect(source.content.to_s).to eq "link"
        expect(translation).to eq :translation
      end
    end

    it "with hit[:href]" do
      doc = Nokogiri::HTML "<html><body></body></html>"
      subject.instance_variable_set :@doc, doc

      url, translation = subject.fetch_source
      expect(url).to be_instance_of Relaton::Bib::Uri
      expect(url.type).to eq "src"
      expect(url.content.to_s).to eq "https://ecma-international.org/publications-and-standards/standards/ecma-370/"
      expect(translation).to eq :translation
    end
  end

  context "#translation_source" do
    it "Japanese" do
      subject.instance_variable_set :@doc, translations

      translations = subject.translation_source

      expect(translations).to be_instance_of Array
      expect(translations.first).to be_instance_of Hash
      expect(translations.first[:ed]).to eq "1"
      expect(translations.first[:source]).to be_instance_of Relaton::Bib::Uri
      expect(translations.first[:source].type).to eq "pdf"
      expect(translations.first[:source].content).to eq "https://ecma-international.org/wp-content/uploads/ECMA-370_1st_edition_japanese_version.pdf"
      expect(translations.first[:source].language).to eq "ja"
      expect(translations.first[:source].script).to eq "Jpan"
    end
  end

  it "#fetch_mem_source" do
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
    subject.instance_variable_set :@hit, hit_mem

    source = subject.fetch_mem_source

    expect(source).to be_instance_of Array
    expect(source.size).to eq 1
    expect(source.first).to be_instance_of Relaton::Bib::Uri
    expect(source.first.type).to eq "pdf"
    expect(source.first.content.to_s).to eq "https://ecma-international.org/wp-content/uploads/Ecma-memento-2025-public.pdf"
  end

  it "#edition_translation_source" do
    subject.instance_variable_set :@doc, translations

    trsource = subject.edition_translation_source "2"
    expect(trsource.first).to be_instance_of Relaton::Bib::Uri
    expect(trsource.first.type).to eq "pdf"
    expect(trsource.first.content.to_s).to eq(
      "https://ecma-international.org/wp-content/uploads/ECMA-370_2nd_edition_december_2006_japanese.pdf"
    )
    expect(trsource.first.language).to eq "ja"
    expect(trsource.first.script).to eq "Jpan"
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

    title = subject.fetch_title
    expect(title.first).to be_instance_of Relaton::Bib::Title
    expect(title.first.content).to eq "title"
    expect(title.first.language).to eq "en"
    expect(title.first.script).to eq "Latn"
  end

  it "#fetch_mem_title" do
    subject.instance_variable_set :@hit, hit_mem

    title = subject.fetch_mem_title
    expect(title.first).to be_instance_of Relaton::Bib::Title
    expect(title.first.content).to eq '"Memento 2025" for year 2025'
    expect(title.first.language).to eq "en"
    expect(title.first.script).to eq "Latn"
  end

  it "#fetch_mem_docidentifier" do
    hit = Nokogiri::HTML <<~HTML
      <div class="entry-content-wrapper clearfix">
        <div><section><div><p>2025</p></div></section></div>
        <div><section><div><p>January 2025</p></div></section></div>
        <div>
          <section>
            <div>
              <p>
                <a href="https://ecma-international.org/wp-content/uploads/Ecma-memento-2025-public.pdf">Download</a>
              </p>
            </div>
          </section>
        </div>
      </div>
    HTML
    subject.instance_variable_set :@hit, hit_mem

    docid = subject.fetch_mem_docidentifier
    expect(docid.first).to be_instance_of Relaton::Bib::Docidentifier
    expect(docid.first.type).to eq "ECMA"
    expect(docid.first.content).to eq "ECMA MEM/2025"
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
    expect(abstract.first).to be_instance_of Relaton::Bib::LocalizedMarkedUpString
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
    expect(date.first).to be_instance_of Relaton::Bib::Date
    expect(date.first.at.to_s).to eq "2022-12"
    expect(date.first.type).to eq "published"
  end

  it "#fetch_mem_date" do
    subject.instance_variable_set :@hit, hit_mem

    date = subject.fetch_mem_date

    expect(date).to be_instance_of Array
    expect(date.first).to be_instance_of Relaton::Bib::Date
    expect(date.first.at.to_s).to eq "2025-01"
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
    expect(relation.first).to be_instance_of Relaton::Bib::Relation
    expect(relation.first.type).to eq "updates"
    expect(relation.first.bibitem).to be_instance_of Relaton::Ecma::ItemData
    expect(relation.first.bibitem.docidentifier.first.content).to eq "ECMA TR/27"
    expect(relation.first.bibitem.docidentifier.first.type).to eq "ECMA"
    expect(relation.first.bibitem.docidentifier.first.primary).to be true
    expect(relation.first.bibitem.edition.content).to eq "1"
    expect(relation.first.bibitem.date.first.at.to_s).to eq "1985-03"
    expect(relation.first.bibitem.date.first.type).to eq "published"
    expect(relation.first.bibitem.source.first.type).to eq "pdf"
    expect(relation.first.bibitem.source.first.content.to_s).to eq(
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
    expect(subject).to receive(:edition_translation_source).with("5.1").and_return [:translation]

    item = subject.parse_editions.first
    expect(item).to be_instance_of Relaton::Ecma::ItemData
    expect(item.source).to be_instance_of Array
    expect(item.source.size).to eq 2
    expect(item.source.first).to be_instance_of Relaton::Bib::Uri
    expect(item.source.first.type).to eq "src"
    expect(item.source.first.content.to_s).to eq "https://262.ecma-international.org/5.1/index.html"
    expect(item.source.last).to eq :translation
    expect(item.edition).to be_instance_of Relaton::Bib::Edition
    expect(item.edition.content).to eq "5.1"
    expect(item.date).to be_instance_of Array
    expect(item.date.size).to eq 1
    expect(item.date.first).to be_instance_of Relaton::Bib::Date
    expect(item.date.first.at.to_s).to eq "2011-06"
    expect(item.date.first.type).to eq "published"
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
          expect(edition).to be_instance_of Relaton::Bib::Edition
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
          expect(dt.first).to be_instance_of Relaton::Bib::Date
          expect(dt.first.at.to_s).to eq date
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

      source = subject.edition_source doc.at("//ul/li")

      expect(source).to be_instance_of Array
      expect(source.size).to eq 1
      expect(source.first).to be_instance_of Relaton::Bib::Uri
      expect(source.first.type).to eq "pdf"
      expect(source.first.content.to_s).to eq "https://www.ecma-international.org/wp-content/uploads/ECMA-254_1st_edition_december_1996.pdf"
    end
  end

  it "#fetch_doctype" do
    doctype = subject.fetch_doctype
    expect(doctype).to be_instance_of Relaton::Bib::Doctype
    expect(doctype.content).to eq "document"
  end
end
