module Nailed
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
        remote_repos = @client.org_repos(organization).map(&:name)
        repos.each do |repo|
          if remote_repos.include?(repo)
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
              unless pull_to_update.empty?
                # update saves the state, so we dont need a db_handler
                # TODO check return code for true if saved correctly
                pull_to_update[0].update(attributes)
                Nailed.log("info", "#{__method__}: Updated #{pr.repo} ##{pr.number} with #{attributes.inspect}")
              else
                db_handler = Pullrequest.first_or_create(attributes)
                Nailed.log("info", "#{__method__}: Created new pullrequest #{pr.repo} ##{pr.number} with #{attributes.inspect}")
              end

              Nailed.save_state(db_handler) unless defined? db_handler
              Nailed.log("info", "#{__method__}: Saved #{attributes.inspect}")
            end unless pulls.empty?
            write_pull_trends(repo)
          else
            Nailed.log("error", "#{__method__}: #{repo} does not exist anymore.")
          end
        end unless repos.nil?
      end
    end

    def update_pull_states
      pulls = Pullrequest.all
      pulls.each do |db_pull|
        number = db_pull.pr_number
        repo = db_pull.repository_rname
        org = Repository.get(repo).organization_oname
        github_pull = @client.pull_request("#{org}/#{repo}", number)
        Nailed.log("info", "#{__method__}: Checking state of pullrequest #{number} from #{org}/#{repo}")
        if github_pull.state == "closed"
          Nailed.log("info", "#{__method__}: Deleting closed pullrequest #{number} from #{org}/#{repo}")
          db_pull.destroy
        end
      end
    end

    def write_pull_trends(repo)
      Nailed.log("info", "#{__method__}: Writing pull trends for #{repo}")
      open = Pullrequest.count(:repository_rname => repo)
      attributes = {:time => Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                    :open => open,
                    :repository_rname => repo}

      db_handler = Pulltrend.first_or_create(attributes)

      Nailed.save_state(db_handler)
      Nailed.log("info", "#{__method__}: Saved #{attributes.inspect}")
    end

    def write_allpull_trends
      Nailed.log("info", "#{__method__}: Writing pull trends for all repos")
      open = Pullrequest.count(:state => "open")
      attributes = {:time => Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                    :open => open}

      db_handler = AllpullTrend.first_or_create(attributes)

      Nailed.save_state(db_handler)
      Nailed.log("info", "#{__method__}: Saved #{attributes.inspect}")
    end
  end
end
