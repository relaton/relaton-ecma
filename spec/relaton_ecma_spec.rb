require "jing"

RSpec.describe RelatonEcma do
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
        bib = RelatonEcma::EcmaBibliography.get "ECMA-6"
        bibitem = replace_date bib.to_xml
        bibitem_file = "spec/fixtures/bibitem.xml"
        write_file bibitem_file, bibitem
        expect(bibitem).to be_equivalent_to read_file bibitem_file

        bibdata = replace_date bib.to_xml(bibdata: true)
        bibdata_file = "spec/fixtures/bibdata.xml"
        write_file bibdata_file, bibdata
        expect(bibdata).to be_equivalent_to read_file bibdata_file
        schema = Jing.new "spec/fixtures/isobib.rng"
        errors = schema.validate bibdata_file
        expect(errors).to eq []
      end
    end
  end

  it "get ECMA techical report" do
    VCR.use_cassette "ecma_tr_18" do
      bib = RelatonEcma::EcmaBibliography.get "ECMA TR/18"
      xml = replace_date bib.to_xml(bibdata: true)
      file = "spec/fixtures/ecma_tr_18.xml"
      write_file file, xml
      expect(xml).to be_equivalent_to read_file file
    end
  end

  it "get ECMA mementos" do
    VCR.use_cassette "ecma_mem_2021" do
      bib = RelatonEcma::EcmaBibliography.get "ECMA MEM/2021"
      xml = replace_date bib.to_xml(bibdata: true)
      file = "spec/fixtures/ecma_mem_2021.xml"
      write_file file, xml
      expect(xml).to be_equivalent_to read_file file
    end
  end
end
