require "open-uri"
require "relaton/index"
require "relaton/bib"
require_relative "ecma/version"
require_relative "ecma/util"
require_relative "ecma/item"
require_relative "ecma/bibitem"
require_relative "ecma/bibdata"
# require "relaton_ecma/xml_parser"
# require "relaton_ecma/hash_converter"
# require "relaton_ecma/ecma_bibliography"
# require "relaton_ecma/data_fetcher"
# require "relaton_ecma/data_parser"

module Relaton
  module Ecma
    # Returns hash of XML reammar
    # @return [String]
    def self.grammar_hash
      # gem_path = File.expand_path "..", __dir__
      # grammars_path = File.join gem_path, "grammars", "*"
      # grammars = Dir[grammars_path].sort.map { |gp| File.read gp }.join
      Digest::MD5.hexdigest Relaton::Ecma::VERSION + Relaton::Bib::VERSION # grammars
    end
  end
end
