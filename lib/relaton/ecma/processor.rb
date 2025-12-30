require "relaton/core/processor"

module Relaton
  module Ecma
    class Processor < Relaton::Core::Processor
      def initialize
        @short = :relaton_ecma
        @prefix = "ECMA"
        @defaultprefix = /^ECMA(-|\s)/
        @idtype = "ECMA"
        @datasets = %w[ecma-standards]
      end

      # @param code [String]
      # @param date [String, nil] year
      # @param opts [Hash]
      # @return [Relaton::Ecma::ItemData, nil]
      def get(code, date, opts)
        require_relative "../ecma"
        Bibliography.get(code, date, opts)
      end

      #
      # Fetch all the documents from a source
      #
      # @param [String] source source name (iec-harmonized-all, iec-harmonized-latest)
      # @param [Hash] opts
      # @option opts [String] :output directory to output documents
      # @option opts [String] :format output format (xml, yaml, bibxml)
      #
      def fetch_data(source, opts)
        require_relative "data_fetcher"
        DataFetcher.fetch(source, **opts)
      end

      # @param xml [String]
      # @return [Relaton::Ecma::ItemData]
      def from_xml(xml)
        require_relative "../ecma"
        Item.from_xml xml
      end

      # @param yaml [String]
      # @return [Relaton::Ecma::ItemData]
      def from_yaml(yaml)
        Item.from_yaml yaml
      end

      # Returns hash of XML grammar
      # @return [String]
      def grammar_hash
        @grammar_hash ||= Ecma.grammar_hash
      end

      #
      # Remove index file
      #
      def remove_index_file
        Relaton::Index.find_or_create(:ECMA, url: true, file: "#{INDEXFILE}.yaml").remove_file
      end
    end
  end
end
