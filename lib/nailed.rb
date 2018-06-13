require 'set'
require 'yaml'

require_relative "nailed/config"
require_relative "nailed/logger"
require_relative "nailed/version"

module Nailed
  extend self

  def logger
    @@logger ||= Logger.new
  end

  def get_colors
    path_to_colors = File.join("config", "colors.yml")
    @@colors ||= YAML.load_file(path_to_colors)
  end

  class Repository
    attr_accessor :name
    attr_accessor :organization

    def initialize(name, organization)
      @name = name
      @organization = organization
      @organization.repositories.add(self)
    end

    def ==(other)
      if !(other.is_a? Repository)
        super
      else
        (@name == other.name && @organization == other.organization)
      end
    end
  end

  class Organization
    attr_accessor :name
    attr_accessor :repositories

    def initialize(name, repos = [])
      @name = name
      @repositories = Repositories.new(self)
      repos.each do |repo|
        @repositories.add(repo)
      end
    end

    def ==(other)
      if !(other.is_a? Organization)
        super
      else
        (@name == other.name)
      end
    end
  end

  class Repositories < Set
    attr_accessor :organization
    def initialize(organization)
      @organization = organization
      super()
    end

    def add(repo)
      if repo.is_a? String
        Repository.new(repo, @organization)
      elsif repo.is_a? Repository
        repo.organization = @organization
        super(repo)
      else
        Nailed.logger.error("Can't handle repository: #{repo}")
      end
    end
  end
end
