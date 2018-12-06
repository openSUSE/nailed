require 'octokit'

require_relative '../changes'
require_relative '../config'
require_relative '../../../db/model'

#
# Nailed::Github
#
module Nailed
  #
  # github helpers
  #
  def list_org_repos(github_client, org)
    repos = self.get_org_repos(org)
    repos.each { |r| puts "- #{r}" }
  end

  class Github < Changes
    attr_reader :client

    def initialize
      Nailed::Config.parse_config
      Octokit.auto_paginate = true
      netrc = Nailed::Config.content["netrc"] || false
      @client = Octokit::Client.new(netrc: netrc)
      @origin = 'github'
    end

    def get_org_repos(org)
      all_repos = self.client.org_repos(org)
    end

    def change_requests(full_repo_name, state)
      @client.pull_requests(full_repo_name, state: state)
    end

    def set_attributes(pr, overlay = {})
      { change_number: pr.number,
        title: pr.title,
        state: pr.state,
        url: pr.html_url,
        created_at: pr.created_at,
        updated_at: pr.updated_at,
        closed_at: pr.closed_at,
        merged_at: pr.merged_at,
        origin: @origin }.merge(overlay)
    end
  end
end
