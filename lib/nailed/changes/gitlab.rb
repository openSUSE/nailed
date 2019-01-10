require 'gitlab'

require_relative '../changes'
require_relative '../config'
require_relative '../../../db/model'

#
# Nailed::Gitlab
#
module Nailed

  class Gitlab < Changes
    attr_reader :client

    def initialize
      Nailed::Config.parse_config
      endpoint = Nailed::Config.content["gitlab"]["endpoint"]
      private_token = Nailed::Config.content["gitlab"]["private_token"]
      @client = ::Gitlab.client(endpoint: endpoint, private_token: private_token)
      @origin = 'gitlab'
    end

    def get_org_repos(org)
      all_repos = self.client.group_projects(org).auto_paginate
    end

    def change_requests(full_repo_name, state)
      @client.merge_requests(full_repo_name, state: state)
    end

    def get_change_requests
      super(state: 'opened')
    end

    def set_attributes(mr, overlay = {})
      { change_number: mr.iid,
        title: mr.title,
        state: mr.state=="opened" ? 'open' : mr.state,
        url: mr.web_url,
        created_at: mr.created_at,
        updated_at: mr.updated_at,
        origin: @origin }.merge(overlay)
    end
  end
end

