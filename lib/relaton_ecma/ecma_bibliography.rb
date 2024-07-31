# frozen_string_literal:true

module RelatonEcma
  # IETF bibliography module
  module EcmaBibliography
    ENDPOINT = "https://raw.githubusercontent.com/relaton/relaton-data-ecma/main/"

    class << self
      #
      # Search for a reference on the IETF website.
      #
      # @param ref [String] the ECMA standard reference to look up (e..g "ECMA-6")
      #
      # @return [Array<Hash>]
      #
      def search(ref)
        refparts = parse_ref ref
        return [] unless refparts

        index = Relaton::Index.find_or_create :ECMA, url: "#{ENDPOINT}index.zip", id_keys: %i[id ed vol]
        index.search { |row| match_ref refparts, row }
      end

      def parse_ref(ref)
        %r{^ECMA[-\s]
          (?<id>(?:\d[\d-]*|\w+/\d+))
          (?:\sed(?<ed>[\d.]+))?
          (?:\svol(?<vol>\d+))?
        }x.match ref
      end

      def match_ref(refparts, row) # rubocop:disable Metrics/AbcSize
        row[:id][:id].match?(/^ECMA[-\s]#{refparts[:id]}/) &&
          (refparts[:ed].nil? || row[:id][:ed] == refparts[:ed]) &&
          (refparts[:vol].nil? || row[:id][:vol] == refparts[:vol])
      end

      # @param code [String] the ECMA standard Code to look up (e..g "ECMA-6")
      # @param year [String] not used
      # @param opts [Hash] not used
      # @return [RelatonEcma::BibliographicItem] Relaton of reference
      def get(code, _year = nil, _opts = {})
        Util.info "Fetching from Relaton repository ...", key: code
        result = fetch_doc(code)
        if result
          Util.info "Found: `#{result.docidentifier.first.id}`", key: code
          # item
        else
          Util.info "Not found.", key: code
        end
        result
      end

      def compare_edition_volume(aaa, bbb)
        comp = bbb[:id][:ed] <=> aaa[:id][:ed]
        comp.zero? ? aaa[:id][:vol] <=> bbb[:id][:vol] : comp
      end

      def fetch_doc(code) # rubocop:disable Metrics/AbcSize
        row = search(code).min { |a, b| compare_edition_volume a, b }
        return unless row

        url = "#{ENDPOINT}#{row[:file]}"
        doc = OpenURI.open_uri url
        hash = YAML.safe_load doc
        hash["fetched"] = Date.today.to_s
        BibliographicItem.from_hash hash
      rescue OpenURI::HTTPError => e
        return if e.io.status.first == "404"

        raise RelatonBib::RequestError, "No document found for #{code} reference. #{e.message}"
      end
    end
  end
end
