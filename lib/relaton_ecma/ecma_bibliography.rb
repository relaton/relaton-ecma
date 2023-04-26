# frozen_string_literal:true

module RelatonEcma
  # IETF bibliography module
  module EcmaBibliography
    ENDPOINT = "https://raw.githubusercontent.com/relaton/relaton-data-ecma/master/"

    class << self
      #
      # Search for a reference on the IETF website.
      #
      # @param ref [String] the ECMA standard reference to look up (e..g "ECMA-6")
      #
      # @return [Array<Hash>]
      #
      def search(ref)
        # Scrapper.scrape_page code
        refparts = parse_ref ref
        index = Relaton::Index.find_or_create :ECMA, url: "#{ENDPOINT}index.zip"
        index.search { |row| match_ref refparts, row }
      end

      def parse_ref(ref)
        %r{^
          (?<id>ECMA(?:[\d-]+|\s\w+/\d+))
          (?:\sed(?<ed>[\d.]+))?
          (?:\svol(?<vol>\d+))?
        }x.match ref
      end

      def match_ref(refparts, row)
        row[:id][:id] == refparts[:id] &&
          (refparts[:ed].nil? || row[:id][:ed] == refparts[:ed]) &&
          (refparts[:vol].nil? || row[:id][:vol] == refparts[:vol])
      end

      # @param code [String] the ECMA standard Code to look up (e..g "ECMA-6")
      # @param year [String] not used
      # @param opts [Hash] not used
      # @return [RelatonEcma::BibliographicItem] Relaton of reference
      def get(code, _year = nil, _opts = {}) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        warn "[relaton-ecma] (\"#{code}\") fetching..."
        result = search(code).min { |a, b| compare_edition_volume a, b }
        if result
          item = fetch_doc(result[:file])
          warn "[relaton-ecma] (\"#{code}\") found #{item.docidentifier.first.id}"
          item
        else
          warn "[relaton-ecma] WARNING no match found online for #{code}. " \
               "The code must be exactly like it is on the standards website."
        end
      rescue OpenURI::HTTPError => e
        return if e.io.status.first == "404"

        raise RelatonBib::RequestError, "No document found for #{code} reference. #{e.message}"
      end

      def compare_edition_volume(aaa, bbb)
        comp = bbb[:id][:ed] <=> aaa[:id][:ed]
        comp.zero? ? aaa[:id][:vol] <=> bbb[:id][:vol] : comp
      end

      def fetch_doc(file)
        url = "#{ENDPOINT}#{file}"
        doc = OpenURI.open_uri url
        hash = YAML.safe_load doc
        hash["fetched"] = Date.today.to_s
        BibliographicItem.from_hash hash
      end
    end
  end
end
