require 'logger'
require 'yaml'
require "octokit"
require "bicho"
require "confstruct"
require "jenkins_api_client"
require_relative "nailed/bugzilla"
require_relative "nailed/github"
require_relative "nailed/jenkins"
require_relative "nailed/version"
require File.join(File.expand_path("..", File.dirname(__FILE__)), "db", "database")

module Nailed
  LOGGER = Logger.new(File.join(File.expand_path("..", File.dirname(__FILE__)), "log", "nailed.log"))
  DEFAULT_CONFIG_PATH =
    File.join(File.expand_path(File.dirname(__FILE__)), "nailed", "default-config.yml")
  DEFAULT_COLORS_PATH =
    File.join(File.expand_path(File.dirname(__FILE__)), "nailed", "default-colors.yml")
  COLORS_PATH =
    File.join(File.expand_path("..", File.dirname(__FILE__)), "config", "colors.yml")
  CONFIG_PATH =
    File.join(File.expand_path("..", File.dirname(__FILE__)), "config", "config.yml")

  extend self
  # generic helpers
  def log(level, msg)
    if get_config["debug"]
      LOGGER.error(msg) if level == "error"
      LOGGER.info(msg) if level == "info"
    end
  end

  def get_config
    if !File.exist?(CONFIG_PATH)
      Confstruct::Configuration.new(
        YAML.load(File.read(DEFAULT_CONFIG_PATH)))
    else
      Confstruct::Configuration.new(
        YAML.load(File.read(CONFIG_PATH)))
    end
  end

  def get_colors
    conf = Confstruct::Configuration.new(
      YAML.load(File.read(DEFAULT_COLORS_PATH)))
    conf.configure(
      YAML.load(File.read(COLORS_PATH))) if File.exist?(COLORS_PATH)
    conf
  end

  # database helpers
  def save_state(db_handler)
    unless db_handler.save
      puts("ERROR: #{__method__}: set debug true and see logfile")
      log("error", "#{__method__}: #{db_handler.errors.inspect}")
    end
  end

  # github helpers
  def get_org_repos(github_client, org)
    all_repos = github_client.org_repos(org)
    all_repos.map(&:name)
  end

  def fill_db_after_migration(github_client)
    get_config["products"].each do |product, values|
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

  def list_org_repos(github_client, org)
    repos = get_org_repos(github_client, org)
    repos.each {|r| puts "- #{r}"}
  end

  def get_github_repos_from_yaml
    repos = []
    get_config["products"].each do |product, values|
      values["repos"].each do |repo|
        repos << repo
      end unless values["repos"].nil?
    end
    repos
  end

  # jenkins helpers
  def get_jenkins_jobs_from_yaml
    jobs = []
    get_config["products"].each do |product, values|
      values["jobs"].each do |job|
        jobs << job
      end unless values["jobs"].nil?
    end
    jobs
  end
end
