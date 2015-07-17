#
# Nailed::Config
#
module Nailed

  DEFAULT_CONFIG_PATH =
    File.join(TOPLEVEL, "nailed", "default-config.yml")
  CONFIG_PATH =
    File.join(TOPLEVEL, "config", "config.yml")
  #
  # Config
  #
  class Config
    # load config.yml once
    def self.content
      unless @@conf
        if !File.exist?(CONFIG_PATH)
          @@conf = DEFAULT_CONFIG_PATH
        else
          @@conf = CONFIG_PATH
        end
      end
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
