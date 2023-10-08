describe RelatonEcma::EcmaBibliography do
  before { RelatonEcma.instance_variable_set :@configuration, nil }

  it "raise HTTP Request Timeout error" do
    exception_io = double "io"
    expect(exception_io).to receive(:status).and_return ["408", "Request Timeout"]
    expect(OpenURI).to receive(:open_uri).and_raise OpenURI::HTTPError.new "Not found", exception_io
    expect do
      described_class.get "ECMA-6"
    end.to raise_error RelatonBib::RequestError
  end

  it "raise HTTP Not Found error" do
    exception_io = double "io"
    expect(exception_io).to receive(:status).and_return ["404", "Not Found"]
    expect(OpenURI).to receive(:open_uri).and_raise OpenURI::HTTPError.new "Not found", exception_io
    expect do
      expect(described_class.get("ECMA-6")).to be_nil
    end.to output(/\[relaton-ecma\] \(ECMA-6\) Not found\./).to_stderr
  end

  context "search" do
    it "return empty array" do
      expect(described_class).to receive(:parse_ref).with("ECMA-6").and_return nil
      expect(described_class.search("ECMA-6")).to eq []
    end
  end
end
