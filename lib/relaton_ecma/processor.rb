require "relaton/processor"

module RelatonEcma
  class Processor < Relaton::Processor
    def initialize
      @short = :relaton_ecma
      @prefix = "ECMA"
      @defaultprefix = /^ECMA(-|\s)/
      @idtype = "ECMA"
    end

    # @param code [String]
    # @param date [String, NilClass] year
    # @param opts [Hash]
    # @return [RelatonEcma::BibliographicItem]
    def get(code, date, opts)
      ::RelatonEcma::EcmaBibliography.get(code, date, opts)
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
  end
end
