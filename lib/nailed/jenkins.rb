require 'jenkins_api_client'

require_relative "./config"
require_relative "../../db/model"

#
# Nailed::Jenkins
#
module Nailed
  class Jenkins
    attr_reader :client

    def initialize
      Nailed::Config.parse_config
      @client = JenkinsApi::Client.new(
        username:    Nailed::Config.content['jenkins']['username'],
        password:    Nailed::Config.content['jenkins']['api_token'],
        ssl:         Nailed::Config.content['jenkins']['ssl'],
        server_ip:   Nailed::Config.content['jenkins']['server_ip'],
        server_port: Nailed::Config.content['jenkins']['server_port'],
        log_level: 4
      )
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
      Nailed::Config.jobs.each do |job|

        # first delete all old parameters
        db_parameters = Jenkinsparameter.select(:name).where(job: job).map(&:name)
        jenkinsapi_parameters = get_build_params(job).map { |p| p[:name] }.uniq
        (db_parameters - jenkinsapi_parameters).each do |param_delete|
          Jenkinsparametervalue.where(jenkinsparameter_name: param_delete,
                                      jenkinsparameter_job: job).delete
          Jenkinsparameter.where(name: param_delete, job: job).destroy
          Nailed.logger.info("#{__method__}: Destroyed #{param_delete} parameter for #{job}")
        end

        Nailed.logger.info("Updating parameters for #{job}")
        get_build_params(job).each do |parameter|
          attributes = {
            type:        parameter[:type],
            job:         job,
            name:        parameter[:name],
            description: parameter[:description],
            default:     parameter[:default]
          }
          begin
            DB[:jenkinsparameters].insert_conflict(:replace).insert(attributes)
            Nailed.logger.debug("#{__method__}: Saved #{attributes.inspect}")
          rescue Exception => e
            Nailed.logger.error("#{__method__}: Could not update #{job} #{parameter[:name]}:\n#{e}")
          end
        end
      end
    end

    def update_builds
      Nailed::Config.jobs.each do |job|
        Nailed.logger.info("Updating builds for #{job}")
        get_builds(job).each do |build|
          build_details = get_build_details(job, build["number"])
          attributes = {
            number: build["number"],
            job:         job,
            url:         build["url"],
            result:      build_details["result"],
            built_on:    build_details["builtOn"],
            description: build_details["description"]
          }
          DB[:jenkinsbuilds].insert_conflict(:replace).insert(attributes)

          Nailed.logger.debug("#{__method__}: Updated #{attributes.inspect}")
        end
      end
    end

    def update_parameter_values
      Nailed::Config.jobs.each do |job|
        builds = get_builds(job)
        builds.each do |build|
          build_number = build["number"]
          build_details = get_build_details(job, build_number)
          parameters = Jenkinsparameter.where(job: job).map(&:name)
          # write JenkinsParameterValue table
          parameters.each do |parameter|
            parameter_section = build_details["actions"].select { |p| p["parameters"] }
            value = begin
                      parameter_section[0]["parameters"].select{
                        |element| element["name"] == parameter
                      }[0]["value"]
                    rescue
                      ""
                    end
            attributes = {
              value:                 value,
              jenkinsparameter_name: parameter,
              jenkinsparameter_job:  job,
              jenkinsbuild_number:   build_number,
              jenkinsbuild_job:      job
            }
            DB[:jenkinsparametervalues].insert_conflict(:replace).insert(attributes)

            Nailed.logger.debug("#{__method__}: Saved #{attributes.inspect}")
          end
          update_equal_builds(job, build_number)
        end
      end
    end

    def update_equal_builds(job, build_number)
      Nailed.logger.debug("#{__method__}: Updating equal builds " \
                         "for #{job}, build number #{build_number}")
      equal_builds = []
      all_jenkins_builds = Jenkinsbuild.where(job: job)
        .order(Sequel.desc(:number)).limit(100)

      lookup_build_parameters = Jenkinsparametervalue
        .select(:jenkinsparameter_name,
                :value)
        .where(jenkinsbuild_job: job,
               jenkinsbuild_number: build_number)
        .naked.all.to_json

      all_jenkins_builds.each do |jenkinsbuild|
        next if jenkinsbuild.number == build_number

        wanted_build_parameters = Jenkinsparametervalue
          .select(:jenkinsparameter_name,
                  :value)
          .where(jenkinsbuild_job: job,
                 jenkinsbuild_number: jenkinsbuild.number)
          .naked.all.to_json

        if wanted_build_parameters == lookup_build_parameters
          equal_builds << jenkinsbuild.number
        end
      end

      build_to_update = Jenkinsbuild.where(job: job, number: build_number)
      build_to_update.update(equal_builds: equal_builds.join(","))
    end
  end
end
