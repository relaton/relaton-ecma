require "relaton/ecma/processor"

describe Relaton::Ecma::Processor do
  it "#intialize" do
    expect(subject.instance_variable_get(:@short)).to eq :relaton_ecma
    expect(subject.instance_variable_get(:@prefix)).to eq "ECMA"
    expect(subject.instance_variable_get(:@defaultprefix)).to eq %r{^ECMA(-|\s)}
    expect(subject.instance_variable_get(:@idtype)).to eq "ECMA"
    expect(subject.instance_variable_get(:@datasets)).to eq %w[ecma-standards]
  end

  it "#get" do
    expect(Relaton::Ecma::Bibliography).to receive(:get).with("ECMA-6", "2014", {})
    subject.get "ECMA-6", "2014", {}
  end

  it "#fetch_data" do
    require "relaton/ecma/data_fetcher"
    expect(Relaton::Ecma::DataFetcher).to receive(:fetch).with("ecma-standards", output: "output", format: "xml")
    subject.fetch_data "ecma-standards", output: "output", format: "xml"
  end

  it "#from_xml" do
    item = subject.from_xml "<bibitem><docidentifier type='ECMA'>ECMA-6</docidentifier></bibitem>"
    expect(item).to be_a Relaton::Ecma::ItemData
  end

  it "#from_yaml" do
    item = subject.from_yaml "---\ndocidentifier:\n- content: ECMA-6\n- type: ECMA\n"
    expect(item).to be_a Relaton::Ecma::ItemData
  end

  it "#grammar_hash" do
    expect(subject.grammar_hash).to be_a String
  end

  it "#remove_index_file" do
    index = double :index
    expect(Relaton::Index).to receive(:find_or_create)
      .with(:ECMA, url: true, file: "#{Relaton::Ecma::INDEXFILE}.yaml").and_return index
    expect(index).to receive(:remove_file)
    subject.remove_index_file
  end
end
