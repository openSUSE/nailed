require 'logger'
require 'yaml'
require "octokit"
require "bicho"
require  File.join(File.expand_path("..", File.dirname(__FILE__)),"db","database")

module Nailed
  LOGGER = Logger.new(File.join(File.expand_path("..", File.dirname(__FILE__)),"log","nailed.log"))

  class Bugzilla
    def initialize
      Bicho.client = Bicho::Client.new(Nailed.get_config["bugzilla"]["url"])
    end

    def get_bugs
      Nailed.get_config["products"].each do |product,values|
        values["versions"].each do |version|
          Nailed.log("info", "#{__method__}: Fetching bugs for #{version}")
          begin
            Bicho::Bug.where(:product => version).each do |bug|
              attributes = {
                :bug_id => bug.id,
                :summary => bug.summary,
                :status => bug.status,
                :is_open => bug.is_open,
                :product_name => bug.product,
                :component => bug.component,
                :severity => bug.severity,
                :priority => bug.priority,
                :whiteboard => bug.whiteboard,
                :assigned_to => bug.assigned_to,
                :creation_time => "#{bug.creation_time.to_date}T#{bug.creation_time.hour}:#{bug.creation_time.min}:#{bug.creation_time.sec}+00:00",
                :last_change_time => "#{bug.last_change_time.to_date}T#{bug.last_change_time.hour}:#{bug.last_change_time.min}:#{bug.last_change_time.sec}+00:00",
                :url => bug.url.gsub(/novell.com\//,'suse.com/show_bug.cgi?id=')
              }

              db_handler = (Bugreport.get(bug.id) || Bugreport.new).update(attributes)
              Nailed.log("info", "#{__method__}: Saved #{attributes.inspect}")
            end
          rescue
            Nailed.log("error","Could not fetch Bugs for #{version}.")
          end
        end unless values["versions"].nil?
      end
    end

    def write_bug_trends
      Nailed.get_config["products"].each do |product,values|
        values["versions"].each do |version|
          Nailed.log("info", "#{__method__}: Writing bug trends for #{version}")
          open = Bugreport.count(:is_open => true, :product_name => version)
          fixed = Bugreport.count(:status => "VERIFIED", :product_name => version) + \
                  Bugreport.count(:status => "RESOLVED", :product_name => version)
          db_handler = Bugtrend.first_or_create(
                       :time => Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                       :open => open,
                       :fixed => fixed,
                       :product_name => version
                       )

          Nailed.save_state(db_handler)
          Nailed.log("info", "#{__method__}: Saved #{attributes.inspect}")
        end unless values["versions"].nil?
      end
    end

    def write_l3_trends
      open = 0
      Nailed.get_config["products"].each do |product,values|
        values["versions"].each do |version|
          Nailed.log("info", "#{__method__}: Aggregating l3 trends for #{version}")
          open += Bugreport.count(:product_name => version, :whiteboard.like => "%openL3%", :is_open => true)
        end unless values["versions"].nil?
      end
      db_handler = L3Trend.first_or_create(
                   :time => Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                   :open => open
                   )

      Nailed.save_state(db_handler)
      Nailed.log("info", "#{__method__}: Saved #{attributes.inspect}")
    end
  end

  class Github
    attr_reader :client

    def initialize
      Octokit.auto_paginate = true
      @client = Octokit::Client.new(:netrc => true)
    end

    def get_open_pulls
      Nailed.get_config["products"].each do |product,values|
        organization = values["organization"]
        repos = values["repos"]
        repos.each do |repo|
          Nailed.log("info", "#{__method__}: Getting open pullrequests for #{organization}/#{repo}")
          pulls = @client.pull_requests("#{organization}/#{repo}")
          pulls.each do |pr|
            attributes = {:pr_number => pr.number,
                         :title => pr.title,
                         :state => pr.state,
                         :url => pr.html_url,
                         :created_at => pr.created_at,
                         :repository_rname => repo}

            # if pr exists dont create a new record
            pull_to_update = Pullrequest.all(:pr_number => pr.number, :repository_rname => repo)
            if pull_to_update
              if pr.state == "closed"
                # delete record if pr.state changed to "closed"
                pull_to_update.destroy
                Nailed.log("info", "#{__method__}: Destroyed closed pullrequest #{pr.repo} ##{pr.number}")
              else
                # update saves the state, so we dont need a db_handler
                # TODO check return code for true if saved correctly
                pull_to_update.update(attributes)
                Nailed.log("info", "#{__method__}: Updated #{pr.repo} ##{pr.number} with #{attributes.inspect}")
              end
            else
              db_handler = Pullrequest.first_or_create(attributes)
              Nailed.log("info", "#{__method__}: Created new pullrequest #{pr.repo} ##{pr.number} with #{attributes.inspect}")
            end

            Nailed.save_state(db_handler) unless defined? db_handler
            Nailed.log("info", "#{__method__}: Saved #{attributes.inspect}")
          end unless pulls.empty?
          write_pull_trends(repo)
        end unless repos.nil?
      end
    end

    def write_pull_trends(repo)
      Nailed.log("info", "#{__method__}: Writing pull trends for #{repo}")
      open = Pullrequest.count(:repository_rname => repo)
      db_handler = Pulltrend.first_or_create(
                   :time => Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                   :open => open,
                   :repository_rname => repo
                   )

      Nailed.save_state(db_handler)
      Nailed.log("info", "#{__method__}: Saved #{attributes.inspect}")
    end
  end

  extend self
  # Generic methods
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
