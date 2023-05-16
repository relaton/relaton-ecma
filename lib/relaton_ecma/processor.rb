require "relaton/processor"

module RelatonEcma
  class Processor < Relaton::Processor
    def initialize
      @short = :relaton_ecma
      @prefix = "ECMA"
      @defaultprefix = /^ECMA(-|\s)/
      @idtype = "ECMA"
      @datasets = %w[ecma-standards]
    end

    # @param code [String]
    # @param date [String, NilClass] year
    # @param opts [Hash]
    # @return [RelatonEcma::BibliographicItem]
    def get(code, date, opts)
      ::RelatonEcma::EcmaBibliography.get(code, date, opts)
    end

    #
    # Fetch all the documents from a source
    #
    # @param [String] source source name (iec-harmonized-all, iec-harmonized-latest)
    # @param [Hash] opts
    # @option opts [String] :output directory to output documents
    # @option opts [String] :format output format (xml, yaml, bibxml)
    #
    def fetch_data(_source, opts)
      DataFetcher.new(**opts).fetch
    end

    # @param xml [String]
    # @return [RelatonEcma::BibliographicItem]
    def from_xml(xml)
      ::RelatonEcma::XMLParser.from_xml xml
    end

    # @param hash [Hash]
    # @return [RelatonEcma::BibliographicItem]
    def hash_to_bib(hash)
      ::RelatonEcma::BibliographicItem.new hash
    end

    # Returns hash of XML grammar
    # @return [String]
    def grammar_hash
      @grammar_hash ||= ::RelatonEcma.grammar_hash
    end

    #
    # Remove index file
    #
    def remove_index_file
      Relaton::Index.find_or_create(:ECMA, url: true).remove_file
    end
  end
end
