#
# Nailed::Github
#
module Nailed
  #
  # github helpers
  #
  def get_org_repos(github_client, org)
    all_repos = github_client.org_repos(org)
    all_repos.map(&:name)
  end

  def list_org_repos(github_client, org)
    repos = get_org_repos(github_client, org)
    repos.each { |r| puts "- #{r}" }
  end

  def get_github_repos_from_yaml
    repos = []
    Config.products.each do |_product, values|
      values["repos"].each do |repo|
        repos << repo
      end unless values["repos"].nil?
    end
    repos
  end

  class Github
    attr_reader :client

    def self.orgs
      @@orgs ||= []
      if @@orgs.empty?
        Config.products.each do |_product, values|
          @@orgs << values["organization"]
        end
      end
      @@orgs
    end

    def initialize
      Octokit.auto_paginate = true
      @client = Octokit::Client.new(netrc: Config["netrc"] || false)
    end

    def get_open_pulls
      Nailed.logger.info("Github: #{__method__}")
      Nailed::Config.products.each do |_product, values|
        organization = values["organization"]
        repos = values["repos"]
        remote_repos = @client.org_repos(organization).map(&:name)
        repos.each do |repo|
          if remote_repos.include?(repo)
            Nailed.logger.info("#{__method__}: Getting open pullrequests for #{organization}/#{repo}")
            pulls = @client.pull_requests("#{organization}/#{repo}")
            pulls.each do |pr|
              attributes = { pr_number:                     pr.number,
                             title:                         pr.title,
                             state:                         pr.state,
                             url:                           pr.html_url,
                             created_at:                    pr.created_at,
                             repository_rname:              repo,
                             repository_organization_oname: organization }

              # if pr exists dont create a new record
              pull_to_update = Pullrequest.all(pr_number: pr.number, repository_rname: repo)
              if pull_to_update.empty?
                db_handler = Pullrequest.first_or_create(attributes)
                Nailed.logger.debug("#{__method__}: Created new pullrequest #{pr.repo} ##{pr.number} with #{attributes.inspect}")
              else
                # update saves the state, so we dont need a db_handler
                # TODO check return code for true if saved correctly
                pull_to_update[0].update(attributes)
                Nailed.logger.debug("#{__method__}: Updated #{pr.repo} ##{pr.number} with #{attributes.inspect}")
              end

              Nailed.save_state(db_handler) unless defined? db_handler
              Nailed.logger.debug("#{__method__}: Saved #{attributes.inspect}")
            end unless pulls.empty?
            write_pull_trends(organization, repo)
          else
            Nailed.logger.error("#{__method__}: #{repo} does not exist anymore.")
          end
        end unless repos.nil?
      end
    end

    def update_pull_states
      pulls = Pullrequest.all
      pulls.each do |db_pull|
        number = db_pull.pr_number
        repo = db_pull.repository_rname
        org = db_pull.repository_organization_oname
        begin
          github_pull = @client.pull_request("#{org}/#{repo}", number)
        rescue Octokit::NotFound
          Nailed.logger.error("#{__method__}: Pullrequest #{org}/#{repo}, ##{number} not found. Deleting from database...")
          db_pull.destroy
          next
        end
        Nailed.logger.info("#{__method__}: Checking state of pullrequest #{number} from #{org}/#{repo}")
        if github_pull.state == "closed"
          Nailed.logger.info("#{__method__}: Deleting closed pullrequest #{number} from #{org}/#{repo}")
          db_pull.destroy
        end
      end
    end

    def write_pull_trends(org, repo)
      Nailed.logger.info("#{__method__}: Writing pull trends for #{org}/#{repo}")
      open = Pullrequest.count(repository_rname: repo)
      attributes = { time:                          Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                     open:                          open,
                     repository_organization_oname: org,
                     repository_rname:              repo }

      db_handler = Pulltrend.first_or_create(attributes)

      Nailed.save_state(db_handler)
      Nailed.logger.debug("#{__method__}: Saved #{attributes.inspect}")
    end

    def write_allpull_trends
      Nailed.logger.info("#{__method__}: Writing pull trends for all repos")
      open = Pullrequest.count(state: "open")
      attributes = { time: Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                     open: open }

      db_handler = AllpullTrend.first_or_create(attributes)

      Nailed.save_state(db_handler)
      Nailed.logger.debug("#{__method__}: Saved #{attributes.inspect}")
    end
  end
end
