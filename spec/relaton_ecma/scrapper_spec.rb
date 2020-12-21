RSpec.describe RelatonEcma::Scrapper do
  it "raise HTTP error" do
    exception_io = double "io"
    expect(OpenURI).to receive(:open_uri).and_raise OpenURI::HTTPError.new "Not found", exception_io
    expect do
      RelatonEcma::EcmaBibliography.get "ECMA-6"
    end.to raise_error RelatonBib::RequestError
  end
end
