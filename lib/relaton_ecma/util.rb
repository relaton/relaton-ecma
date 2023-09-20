module RelatonEcma
  module Util
    extend RelatonBib::Util

    def self.logger
      RelatonEcma.configuration.logger
    end
  end
end
