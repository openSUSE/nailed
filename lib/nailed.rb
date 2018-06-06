require "yaml"
require "octokit"
require "bicho"

TOPLEVEL = File.expand_path("..", File.dirname(__FILE__))

require_relative "nailed/config"
require_relative "nailed/logger"
require_relative "nailed/version"

module Nailed
  extend self

  def logger
    @@logger ||= Logger.new
  end

  def get_colors
    conf = File.join(TOPLEVEL, "config", "colors.yml")
    YAML.load_file(conf)
  end
end
