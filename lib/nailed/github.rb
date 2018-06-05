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

    def get_pull_requests(state: 'all')
      Nailed.logger.info("Github: #{__method__}")
      Nailed::Config.products.each do |_product, values|
        organization = values["organization"]
        repos = values["repos"]
        remote_repos = @client.org_repos(organization).map(&:name)
        repos.each do |repo|
          if remote_repos.include?(repo)
            Nailed.logger.info("#{__method__}: Getting #{state} pullrequests for #{organization}/#{repo}")
            pulls = @client.pull_requests("#{organization}/#{repo}", :state => state)
            pulls.each do |pr|
              attributes = { pr_number:                     pr.number,
                             title:                         pr.title,
                             state:                         pr.state,
                             url:                           pr.html_url,
                             created_at:                    pr.created_at,
                             updated_at:                    pr.updated_at,
                             closed_at:                     pr.closed_at,
                             merged_at:                     pr.merged_at,
                             repository_rname:              repo,
                             repository_organization_oname: organization }

              begin
                DB[:pullrequests].insert_conflict(:replace).insert(attributes)
              rescue Exception => e
                Nailed.logger.error("Could not write pullrequest:\n#{e}")
              end

              Nailed.logger.debug(
                "#{__method__}: Created/Updated pullrequest #{pr.repo} " \
                "##{pr.number} with #{attributes.inspect}")
            end unless pulls.empty?
            write_pull_trends(organization, repo)
          else
            Nailed.logger.error("#{__method__}: #{repo} does not exist.")
          end
        end unless repos.nil?
      end
    end

    def write_pull_trends(org, repo)
      Nailed.logger.info("#{__method__}: Writing pull trends for #{org}/#{repo}")
      open = Pullrequest.where(repository_rname: repo, state: "open").count
      closed = Pullrequest.where(repository_rname: repo, state: "closed").count
      attributes = { time:                          Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                     open:                          open,
                     closed:                        closed,
                     repository_organization_oname: org,
                     repository_rname:              repo }

      begin
        DB[:pulltrends].insert(attributes)
      rescue Exception => e
        Nailed.logger.error("Could not write pull trend for #{org}/#{repo}:\n#{e}")
      end

      Nailed.logger.debug("#{__method__}: Saved #{attributes.inspect}")
    end

    def write_allpull_trends
      Nailed.logger.info("#{__method__}: Writing pull trends for all repos")
      open = Pullrequest.where(state: "open").count
      closed = Pullrequest.where(state: "closed").count
      attributes = { time: Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                     open: open,
                     closed: closed}
      begin
        DB[:allpull_trends].insert(attributes)
      rescue Exception => e
        Nailed.logger.error("Could not write allpull trend:\n#{e}")
      end

      Nailed.logger.debug("#{__method__}: Saved #{attributes.inspect}")
    end
  end
end
