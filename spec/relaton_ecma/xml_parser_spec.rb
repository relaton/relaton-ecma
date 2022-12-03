describe RelatonEcma::XMLParser do
  it "returns ECMA bibliographic item" do
    item = RelatonEcma::XMLParser.send :bib_item, title: ["title"]
    expect(item).to be_instance_of RelatonEcma::BibliographicItem
  end
end
