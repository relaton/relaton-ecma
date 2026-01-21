describe RelatonEcma::EcmaBibliography do
  describe ".get" do
    context "unsuccessful" do
      let(:agent) { instance_double Mechanize }
      before { expect(Mechanize).to receive(:new).and_return agent }

      it "raise HTTP Request Timeout error" do
        expect(agent).to receive(:get).and_raise Timeout::Error
        expect do
          described_class.get "ECMA-6"
        end.to raise_error RelatonBib::RequestError
      end

      it "raise HTTP Not Found error" do
        expect(agent).to receive(:get).and_raise Mechanize::ResponseCodeError.new(double(code: 404), "404")
        expect do
          expect(described_class.get("ECMA-6")).to be_nil
        end.to output(/\[relaton-ecma\] INFO: \(ECMA-6\) Not found\./).to_stderr_from_any_process
      end
    end
  end

  context "search" do
    it "return empty array" do
      expect(described_class).to receive(:parse_ref).with("ECMA-6").and_return nil
      expect(described_class.search("ECMA-6")).to eq []
    end
  end
end
