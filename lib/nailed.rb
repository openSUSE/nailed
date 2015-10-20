require 'logger'
require 'yaml'
require "octokit"
require "bicho"
require "jenkins_api_client"

TOPLEVEL = File.expand_path("..", File.dirname(__FILE__))

require_relative "nailed/config"
require_relative "nailed/bugzilla"
require_relative "nailed/github"
require_relative "nailed/jenkins"
require_relative "nailed/version"

require File.join(TOPLEVEL, "db", "database")

module Nailed

  #
  # Logger
  #

  LOGGER = Logger.new(File.join(TOPLEVEL,"log","nailed.log"))

  extend self
  # generic helpers
  def log(level,msg)
    if get_config["debug"]
      LOGGER.error(msg) if level == "error"
      LOGGER.info(msg) if level == "info"
    end
  end

  def get_colors
    conf = File.join(TOPLEVEL,"config","colors.yml")
    YAML.load_file(conf)
  end

  #
  # database helpers
  #
  def save_state(db_handler)
    unless db_handler.save
      puts("ERROR: #{__method__}: set debug true and see logfile")
      log("error", "#{__method__}: #{db_handler.errors.inspect}")
    end
  end

  #
  # jenkins helpers
  #
  def get_jenkins_jobs_from_yaml
    jobs = []
    Config.products.each do |product,values|
      values["jobs"].each do |job|
        jobs << job
      end unless values["jobs"].nil?
    end
    jobs
  end
end
