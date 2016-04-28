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
      @@conf ||= File.join(TOPLEVEL, "config", "config.yml")
      begin
	@@yaml ||= YAML.load_file(@@conf)
      rescue Exception => e
	# 'log' to stderr since logger might not be initialized yet
	STDERR.puts "Can't load '#{@@conf}': #{e}"
      end
      @@yaml
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
