require 'yaml'

require_relative '../nailed'

module Nailed
  class Config
    def self.parse_config(path_to_config = nil)
      path_to_config ||= File.join(__dir__, "..", "..", "config", "config.yml")
      begin
        @@content = YAML.load_file(path_to_config) || nil
      rescue Exception => e
        STDERR.puts("Can't load '#{path_to_config}': #{e}")
        exit 1
      end

      self.is_valid?

      # init class variables:
      @@organizations = []
      @@content['organizations'].each do |org|
        org_obj = Organization.new(org['name'])
        org['repositories'].each do |repo|
          org_obj.repositories.add(repo)
        end
        @@organizations.push(org_obj)
      end

      @@all_repositories = []
      @@organizations.each do |org|
        @@all_repositories.concat(org.repositories.to_a)
      end
    end

    def self.is_valid?
      if @@content.nil? || @@content.empty?
        abort("Config empty or corrupted")
      elsif @@content['products'].nil? || @@content['products'].empty?
        abort("Config incomplete: No products found")
      end
      true
    end

    # attr_accessor:
    def self.products
      @@content['products']
    end

    def self.organizations
      @@organizations
    end

    def self.all_repositories
      @@all_repositories
    end

    def self.content
      @@content
    end
  end
end
