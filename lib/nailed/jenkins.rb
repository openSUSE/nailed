module Nailed
  class Jenkins
    def initialize
      @client = JenkinsApi::Client.new(
        server_ip:    Nailed::Config["jenkins"]["server_ip"],
        server_port:  Nailed::Config["jenkins"]["server_port"] || 8080,
        ssl:          Nailed::Config["jenkins"]["ssl"] || false,
        username:     Nailed::Config["jenkins"]["username"],
        password:     Nailed::Config["jenkins"]["api_token"],
        log_location: Nailed.logfile,
        log_level:    (logger.level == Logger::FATAL) ? 4 : 1)
    end

    def get_builds(job_name)
      @client.job.get_builds(job_name)
    end

    def get_build_params(job_name)
      @client.job.get_build_params(job_name)
    end

    def get_build_details(job_name, build_num)
      @client.job.get_build_details(job_name, build_num)
    end

    def update_parameters
      Nailed.get_jenkins_jobs_from_yaml.each do |job|
        # first delete all old parameters
        db_parameters = JenkinsParameter.all(job: job).map(&:name)
        jenkinsapi_parameters = get_build_params(job).map { |p| p[:name] }.uniq
        (db_parameters - jenkinsapi_parameters).each do |param_delete|
          JenkinsParameter.get(param_delete, job).destroy
          Nailed.logger.info("#{__method__}: Destroyed #{param_delete} parameter for #{job}")
        end
        # second updating parameters
        Nailed.logger.info("#{__method__}: Updating parameters for #{job}")
        parameters = get_build_params(job)
        parameters.each do |parameter|
          attributes = {
            type:        parameter[:type],
            job:         job,
            name:        parameter[:name],
            description: parameter[:description],
            default:     parameter[:default]
          }
          db_handler = (JenkinsParameter.get(parameter[:name], job) || JenkinsParameter.new).update(attributes)

          Nailed.logger.info("#{__method__}: Saved #{attributes.inspect}")
        end
      end
    end

    def update_build_numbers
      Nailed.get_jenkins_jobs_from_yaml.each do |job|
        Nailed.logger.info("#{__method__}: Updating builds for #{job}")
        builds = get_builds(job)
        builds.each do |build|
          attributes = {
            number: build["number"],
            job:    job,
            url:    build["url"]
          }
          db_handler = JenkinsBuild.first_or_create(attributes)

          Nailed.save_state(db_handler)
          Nailed.logger.info("#{__method__}: Saved #{attributes.inspect}")
        end
      end
    end

    def update_build_details
      Nailed.get_jenkins_jobs_from_yaml.each do |job|
        Nailed.logger.info("#{__method__}: Updating build details for #{job}")
        builds = get_builds(job)
        builds.each do |build|
          build_number = build["number"]
          parameters = JenkinsParameter.all(job: job).map(&:name)
          build_details = get_build_details(job, build_number)

          # update JenkinsBuild table with the result
          attributes = {
            result:      build_details["result"],
            built_on:    build_details["builtOn"],
            description: build_details["description"]
          }
          db_handler = JenkinsBuild.all(job: job, number: build_number).update(attributes)
          Nailed.logger.info("#{__method__}: Updated #{attributes.inspect} on Jenkins build ##{build_number}")

          # write JenkinsParameterValue table
          parameters.each do |parameter|
            parameter_section = build_details["actions"].select { |p| p["parameters"] }
            # FIXME: a parameter in parameter_section[0]["parameters"] could be missing
            # not sure yet why this happens
            value = begin
              parameter_section[0]["parameters"].select { |element| element["name"] == parameter }[0]["value"]
            rescue
              ""
            end
            attributes = {
              value:                  value,
              jenkins_parameter_name: parameter,
              jenkins_parameter_job:  job,
              jenkins_build_number:   build_number,
              jenkins_build_job:      job
            }
            db_handler = JenkinsParameterValue.first_or_create(attributes)

            Nailed.save_state(db_handler)
            Nailed.logger.info("#{__method__}: Saved #{attributes.inspect}")
          end
          update_equal_builds(job, build_number)
        end
      end
    end

    def update_equal_builds(job, build_number)
      Nailed.logger.info("#{__method__}: Updating equal builds for #{job}")
      equal_builds = []
      all_jenkins_builds = JenkinsBuild.all(job: job, limit: 100, order: :number.desc)
      all_jenkins_builds.each do |jenkins_build|
        next if jenkins_build.number == build_number
        wanted_build_parameters = JenkinsParameterValue.all(jenkins_build_job: job, jenkins_build_number: jenkins_build.number).to_json(only: [:jenkins_parameter_name, :value])
        lookup_build_parameters = JenkinsParameterValue.all(jenkins_build_job: job, jenkins_build_number: build_number).to_json(only: [:jenkins_parameter_name, :value])
        if wanted_build_parameters == lookup_build_parameters
          equal_builds << jenkins_build.number
        end
      end
      build_to_update = JenkinsBuild.all(job: job, number: build_number)
      build_to_update.update(equal_builds: equal_builds.join(","))
    end
  end
end
