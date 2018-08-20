require 'yaml'

require_relative '../nailed'

module Nailed
  class Config
    class << self
      def parse_config
        is_valid?

        # init class variables:
        @@organizations = []
        (load_content['organizations'] || []).each do |org|
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

      def is_valid?
        if load_content.nil? || load_content.empty?
          abort("Config empty or corrupted")
        elsif load_content['products'].nil? || load_content['products'].empty?
          abort("Config incomplete: No products found")
        end
        true
      end

      # attr_accessor:
      def products
        load_content['products']
      end

      def organizations
        @@organizations
      end

      def all_repositories
        @@all_repositories
      end

      def content
        load_content
      end

      private

      def load_content
        path_to_config ||= File.join(__dir__, "..", "..", "config", "config.yml")
        begin
          @@content ||= YAML.load_file(path_to_config)
        rescue Exception => e
          STDERR.puts("Can't load '#{path_to_config}': #{e}")
          exit 1
        end
      end
    end
  end
end
