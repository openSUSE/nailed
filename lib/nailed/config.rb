#
# Nailed::Config
#
module Nailed

  #
  # Config
  #
  class Config
    # load config.yml once
    def self.content
      @@conf ||= File.join(TOPLEVEL,"config","config.yml")
      @@yaml ||= YAML.load_file(@@conf)
    end
    # access config section by name
    def self.[] name
      self.content[name]
    end
    # access products section, abort if empty
    def self.products
      self.content["products"] || abort("No products defined in config.yml")
    end
  end

end
