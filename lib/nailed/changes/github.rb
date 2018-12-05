require 'octokit'

require_relative '../config'
require_relative '../../nailed'
require_relative '../../../db/model'

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

  class Github
    attr_reader :client

    def initialize
      Nailed::Config.parse_config
      Octokit.auto_paginate = true
      netrc = Nailed::Config.content["netrc"] || false
      @client = Octokit::Client.new(netrc: netrc)
    end

    def get_pull_requests(state: 'open')
      Nailed.logger.info("Github: #{__method__}")
      Nailed::Config.all_repositories.each do |repo|
        updated_pullrequests = []
        full_repo_name = "#{repo.organization.name}/#{repo.name}"
        Nailed.logger.info("#{__method__}: Getting #{state} pullrequests " \
                           "for #{full_repo_name}")
        begin
          retries ||= 0
          pulls = @client.pull_requests("#{full_repo_name}", :state => state)
        rescue Exception => e
          retry if (retries += 1) < 2
          Nailed.logger.error("Could not get Pulls for #{full_repo_name}: #{e}")
          next
        end
        pulls.each do |pr|
          attributes = { change_number: pr.number,
                         title: pr.title,
                         state: pr.state,
                         url: pr.html_url,
                         created_at: pr.created_at,
                         updated_at: pr.updated_at,
                         closed_at: pr.closed_at,
                         merged_at: pr.merged_at,
                         rname: repo.name,
                         oname: repo.organization.name,
                         origin: "github" }

          begin
            DB[:changerequests].insert_conflict(:replace).insert(attributes)
            updated_pullrequests.append(pr.number)
          rescue Exception => e
            Nailed.logger.error("Could not write pullrequest:\n#{e}")
            next
          end

          Nailed.logger.debug(
            "#{__method__}: Created/Updated pullrequest #{repo.name} " \
            "##{pr.number} with #{attributes.inspect}")
        end unless pulls.empty?

        # check for old pullrequests of this repo and close them:
        Changerequest.select(:change_number, :state, :rname).where(state: "open", rname: repo.name).each do |pr|
          unless updated_pullrequests.include? pr.change_number
            begin
              pr.update(state: "closed")
              Nailed.logger.info("Closed old pullrequest: #{repo.name}/#{pr.change_number}")
            rescue Exception => e
              Nailed.logger.error("Could not close pullrequest #{repo.name}/#{pr.change_number}:\n#{e}")
            end
          end
        end

        write_pulltrends(repo.organization.name, repo.name)
      end
    end

    def write_pulltrends(org, repo)
      Nailed.logger.info("#{__method__}: Writing pull trends for #{org}/#{repo}")
      open = Changerequest.where(rname: repo, state: "open").count
      closed = Changerequest.where(rname: repo, state: "closed").count
      attributes = { time: Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                     open: open,
                     closed: closed,
                     oname: org,
                     rname: repo,
                     origin: "github" }

      begin
        DB[:changetrends].insert(attributes)
      rescue Exception => e
        Nailed.logger.error("Could not write pull trend for #{org}/#{repo}:\n#{e}")
      end

      Nailed.logger.debug("#{__method__}: Saved #{attributes.inspect}")
    end

    def write_allpulltrends
      Nailed.logger.info("#{__method__}: Writing pull trends for all repos")
      open = Changerequest.where(state: "open").count
      closed = Changerequest.where(state: "closed").count
      attributes = { time: Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                     open: open,
                     closed: closed,
                     origin: "github" }
      begin
        DB[:allchangetrends].insert(attributes)
      rescue Exception => e
        Nailed.logger.error("Could not write allpull trend:\n#{e}")
      end

      Nailed.logger.debug("#{__method__}: Saved #{attributes.inspect}")
    end
  end
end
