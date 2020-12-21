require "nokogiri"
require "open-uri"
require "relaton_bib"
require "relaton_ecma/version"
require "relaton_ecma/scrapper"
require "relaton_ecma/ecma_bibliography"

module RelatonEcma
  # Returns hash of XML reammar
  # @return [String]
  def self.grammar_hash
    gem_path = File.expand_path "..", __dir__
    grammars_path = File.join gem_path, "grammars", "*"
    grammars = Dir[grammars_path].sort.map { |gp| File.read gp }.join
    Digest::MD5.hexdigest grammars
  end
end
