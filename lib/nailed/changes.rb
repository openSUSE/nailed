module Nailed

  #
  # helpers
  #
  def list_org_repos(client, org)
    repos = client.get_org_repos(org)
    repos = repos.map(&:name)
    repos.each { |r| puts "- #{r}" }
  end

  def write_allchangetrends
    Nailed.logger.info("#{__method__}: Writing change trends for all repos")
    time = Time.new.strftime("%Y-%m-%d %H:%M:%S")
    origin = Changerequest.select(:origin).distinct.naked.all.map{|o| o[:origin]}
    origin.each do |vcs|
      open = Changerequest.where(state: "open", origin: vcs).count
      closed = Changerequest.where(state: "closed", origin: vcs).count
      attributes = { time: time,
                     open: open,
                     closed: closed,
                     origin: vcs }
      begin
        DB[:allchangetrends].insert(attributes)
      rescue Exception => e
        Nailed.logger.error("Could not write all #{origin} change trends:\n#{e}")
      end

      Nailed.logger.debug("#{__method__}: Saved #{attributes.inspect}")
    end
  end

  class Changes

    def get_change_requests(state: 'open')
      Nailed.logger.info("#{@origin}: #{__method__}")
      Nailed::Config.all_repositories[@origin].each do |repo|
        updated_changerequests = []
        full_repo_name = "#{repo.organization.name}/#{repo.name}"
        Nailed.logger.info("#{__method__}: Getting #{state} " \
                           "#{@origin} changerequests " \
                           "for #{full_repo_name}")
        begin
          retries ||= 0
          changes = change_requests(full_repo_name, state)
        rescue Exception => e
          retry if (retries += 1) < 2
          Nailed.logger.error("Could not get #{@origin} Changes for " \
                              "#{full_repo_name}: #{e}")
          next
        end

        changes.each do |change|
          attributes = set_attributes(change, {
                                      rname: repo.name,
                                      oname: repo.organization.name })
          begin
            DB[:changerequests].insert_conflict(:replace).insert(attributes)
            updated_changerequests.append(attributes[:change_number])
          rescue Exception => e
            Nailed.logger.error("Could not write #{@origin} changerequest:\n#{e}")
            next
          end

          Nailed.logger.debug(
            "#{__method__}: Created/Updated #{@origin} changerequest #{repo.name} " \
            "##{attributes[:change_number]} with #{attributes.inspect}")
        end unless changes.empty?

        # check for old changerequests of this repo and close them:
        Changerequest.select(:change_number,
                             :state,
                             :oname,
                             :rname,
                             :origin).where(state: "open",
                                           rname: repo.name,
                                           origin: @origin).each do |change|
          unless updated_changerequests.include? change.change_number
            begin
              change.update(state: "closed")
              Nailed.logger.info("Closed old #{@origin} changerequest: " \
                                 "#{repo.name}/#{change.change_number}")
            rescue Exception => e
              Nailed.logger.error("Could not close #{@origin} changerequest " \
                                  "#{repo.name}/#{change.change_number}:\n#{e}")
            end
          end
        end

        write_changetrends(repo.organization.name, repo.name)
      end
    end

    def write_changetrends(org, repo)
      Nailed.logger.info("#{__method__}: Writing #{@origin} change trends for #{org}/#{repo}")
      open = Changerequest.where(rname: repo, state: "open", origin: @origin).count
      closed = Changerequest.where(rname: repo, state: "closed", origin: @origin).count
      attributes = { time: Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                     open: open,
                     closed: closed,
                     oname: org,
                     rname: repo,
                     origin: @origin }

      begin
        DB[:changetrends].insert(attributes)
      rescue Exception => e
        Nailed.logger.error("Could not write #{@origin} change trend for #{org}/#{repo}:\n#{e}")
      end

      Nailed.logger.debug("#{__method__}: Saved #{attributes.inspect}")
    end
  end
end
