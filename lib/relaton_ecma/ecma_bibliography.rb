# frozen_string_literal:true

module RelatonEcma
  # IETF bibliography module
  module EcmaBibliography
    class << self
      # @param code [String] the ECMA standard Code to look up (e..g "ECMA-6")
      # @return [RelatonBib::BibliographicEcma]
      def search(code)
        Scrapper.scrape_page code
      end

      # @param code [String] the ECMA standard Code to look up (e..g "ECMA-6")
      # @param year [String] not used
      # @param opts [Hash] not used
      # @return [RelatonBib::BibliographicItem] Relaton of reference
      def get(code, _year = nil, _opts = {})
        warn "[relaton-ecma] (\"#{code}\") fetching..."
        result = search code
        warn "[relaton-ecma] (\"#{code}\") found #{result.docidentifier.first.id}"
        result
      end
    end
  end
end
