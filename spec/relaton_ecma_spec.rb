RSpec.describe RelatonEcma do
  before { RelatonEcma.instance_variable_set :@configuration, nil }

  it "has a version number" do
    expect(RelatonEcma::VERSION).not_to be nil
  end

  it "returs grammar hash" do
    hash = RelatonEcma.grammar_hash
    expect(hash).to be_instance_of String
    expect(hash.size).to eq 32
  end

  context "get ECMA standard" do
    it "and return RelatonXML" do
      VCR.use_cassette "ecma_6" do
        expect do
          bib = RelatonEcma::EcmaBibliography.get "ECMA-6"
          bibitem = bib.to_xml
          bibitem_file = "spec/fixtures/bibitem.xml"
          write_file bibitem_file, bibitem
          expect(bibitem).to be_equivalent_to read_file bibitem_file

          bibdata = bib.to_xml(bibdata: true)
          bibdata_file = "spec/fixtures/bibdata.xml"
          write_file bibdata_file, bibdata
          expect(bibdata).to be_equivalent_to read_file bibdata_file
          schema = Jing.new "grammars/relaton-ecma-compile.rng"
          errors = schema.validate bibdata_file
          expect(errors).to eq []
        end.to output(%r{
          \[relaton-ecma\]\s\(ECMA-6\)\sFetching\sfrom\sRelaton\srepository\s\.\.\.\n
          \[relaton-ecma\]\s\(ECMA-6\)\sFound:\s`ECMA-6`
        }x).to_stderr
      end
    end

    it "with specific edition", vcr: { cassette_name: "ecma_262_ed5_1" } do
      bib = RelatonEcma::EcmaBibliography.get "ECMA-262 ed5.1"
      expect(bib.docidentifier.first.id).to eq "ECMA-262"
      expect(bib.edition.content).to eq "5.1"
    end

    it "with specific edition and volume", vcr: { cassette_name: "ecma_269_ed3_vol2" } do
      bib = RelatonEcma::EcmaBibliography.get "ECMA-269 ed3 vol2"
      expect(bib.docidentifier.first.id).to eq "ECMA-269"
      expect(bib.edition.content).to eq "3"
      expect(bib.extent.first.reference_from).to eq "2"
    end

    it "last edition", vcr: { cassette_name: "ecma_269" } do
      bib = RelatonEcma::EcmaBibliography.get "ECMA 269"
      expect(bib.docidentifier.first.id).to eq "ECMA-269"
      expect(bib.edition.content).to eq "9"
    end

    it "first volume", vcr: { cassette_name: "ecma_269_ed3" } do
      bib = RelatonEcma::EcmaBibliography.get "ECMA-269 ed3"
      expect(bib.docidentifier.first.id).to eq "ECMA-269"
      expect(bib.edition.content).to eq "3"
      expect(bib.extent.first.reference_from).to eq "1"
    end
  end

  it "get ECMA techical report" do
    VCR.use_cassette "ecma_tr_18" do
      bib = RelatonEcma::EcmaBibliography.get "ECMA TR/18"
      xml = bib.to_xml(bibdata: true)
      file = "spec/fixtures/ecma_tr_18.xml"
      write_file file, xml
      expect(xml).to be_equivalent_to read_file file
    end
  end

  it "get ECMA mementos" do
    VCR.use_cassette "ecma_mem_2021" do
      bib = RelatonEcma::EcmaBibliography.get "ECMA MEM/2021"
      xml = bib.to_xml(bibdata: true)
      file = "spec/fixtures/ecma_mem_2021.xml"
      write_file file, xml
      expect(xml).to be_equivalent_to read_file file
    end
  end
end
