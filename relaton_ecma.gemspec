require_relative "lib/relaton_ecma/version"

Gem::Specification.new do |spec| # rubocop:disable Metrics/BlockLength
  spec.name          = "relaton-ecma"
  spec.version       = RelatonEcma::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com"]

  spec.summary       = "RelatonIetf: retrieve ECMA Standards for bibliographic " \
                       "use using the BibliographicItem model"
  spec.description   = <<~DESCRIPTION
    RelatonEcma: retrieve ECMA Standards for bibliographic use
    using the BibliographicItem model.
  DESCRIPTION
  spec.homepage      = "https://github.com/metanorma/relaton-ecma"
  spec.license       = "BSD-2-Clause"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  spec.metadata["homepage_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "mechanize", "~> 2.10"
  spec.add_dependency "relaton-bib", "~> 1.20.0"
  spec.add_dependency "relaton-index", "~> 0.2.4"
end
