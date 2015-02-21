require 'logger'
require 'yaml'
require "octokit"
require "bicho"
require_relative "nailed/bugzilla"
require_relative "nailed/github"
require_relative "nailed/version"
require  File.join(File.expand_path("..", File.dirname(__FILE__)),"db","database")

module Nailed
  LOGGER = Logger.new(File.join(File.expand_path("..", File.dirname(__FILE__)),"log","nailed.log"))

  extend self
  def log(level,msg)
    if get_config["debug"]
      LOGGER.error(msg) if level == "error"
      LOGGER.info(msg) if level == "info"
    end
  end

  def get_config
    conf = File.join(File.expand_path("..", File.dirname(__FILE__)),"config","config.yml")
    YAML.load_file(conf)
  end

  def get_org_repos(github_client, org)
    all_repos = github_client.org_repos(org)
    all_repos.map(&:name)
  end

  def fill_db_after_migration(github_client)
    get_config["products"].each do |product,values|
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

  def save_state(db_handler)
    unless db_handler.save
      puts("ERROR: #{__method__}: see logfile")
      log("error", "#{__method__}: #{db_handler.errors.inspect}")
    end
  end
end
