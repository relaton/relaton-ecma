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

  context "get ECMA document" do
    it "and return RelatonXML" do
      VCR.use_cassette "ecma_6" do
        bib = RelatonEcma::EcmaBibliography.get "ECMA-6"
        bibitem = bib.to_xml
        bibitem_file = "spec/fixtures/bibitem.xml"
        write_file bibitem_file, bibitem unless File.exist? bibitem_file
        expect(bibitem).to be_equivalent_to read_file bibitem_file

        bibdata = bib.to_xml bibdata: true
        bibdata_file = "spec/fixtures/bibdata.xml"
        write_file bibdata_file, bibdata unless File.exist? bibdata_file
        expect(bibdata).to be_equivalent_to read_file bibdata_file
        schema = Jing.new "spec/fixtures/isobib.rng"
        errors = schema.validate bibdata_file
        expect(errors).to eq []
      end
    end
  end
end
