require 'yaml'
require "octokit"
require "bicho"
require "jenkins_api_client"

TOPLEVEL = File.expand_path("..", File.dirname(__FILE__))

require_relative "nailed/logger"
require_relative "nailed/config"
require_relative "nailed/bugzilla"
require_relative "nailed/github"
require_relative "nailed/jenkins"
require_relative "nailed/version"

require File.join(TOPLEVEL, "db", "database")

module Nailed

  DEFAULT_COLORS_PATH =
    File.join(File.expand_path(File.dirname(__FILE__)), "config", "default-colors.yml")
  COLORS_PATH =
    File.join(File.expand_path("..", File.dirname(__FILE__)), "config", "colors.yml")

  extend self
  # generic helpers
  def log(level,msg)
    if Config["debug"]
      LOGGER.error(msg) if level == "error"
      LOGGER.info(msg) if level == "info"
    end
  end

  def get_colors
    conf = Confstruct::Configuration.new(
      YAML.load(File.read(DEFAULT_COLORS_PATH)))
    conf.configure(
      YAML.load(File.read(COLORS_PATH))) if File.exist?(COLORS_PATH)
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
  # needs to be splitted into Github and Bugzilla parts
  #
  def fill_db_after_migration(github_client)
    Config.products.each do |product,values|
      organization = values["organization"]
      values["versions"].each do |version|
        db_handler = Product.first_or_create(:name => version)
        save_state(db_handler)
      end unless values["versions"].nil?
      unless organization.nil?
        db_handler = Organization.first_or_create(:oname => organization)
        save_state(db_handler)
        org_repos_github = get_org_repos(github_client, organization)
        org_repos_yml = values["repos"]
        org_repos_yml.each do |org_repo|
          if org_repos_github.include?(org_repo)
            db_handler = Repository.first_or_create(:rname => org_repo, :organization_oname => organization)
            save_state(db_handler)
          end
        end
      end
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
