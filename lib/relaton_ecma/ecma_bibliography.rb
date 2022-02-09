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
        if result
          warn "[relaton-ecma] (\"#{code}\") found #{result.docidentifier.first.id}"
        else
          warn "[relaton-ecma] WARNING no match found online for #{code}. "\
               "The code must be exactly like it is on the standards website."
        end
        result
      end
    end
  end
end
