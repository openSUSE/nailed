require 'yaml'

require_relative '../nailed'

module Nailed
  class Config
    class << self

      # list of supported version-control-systems
      @@SUPPORTED_VCS = [ 'github', 'gitlab' ]

      def parse_config
        is_valid?

        # init class variables for supported VCS's
        init_vcs

        # init class variables:
        organizations.keys.each do |vcs|
          (load_content[vcs]['organizations'] || []).each do |org|
            org_obj = Organization.new(org['name'])
            org['repositories'].each do |repo|
              org_obj.repositories.add(repo)
            end
            @@organizations[vcs].push(org_obj)
          end

          @@organizations[vcs].each do |org|
            @@all_repositories[vcs].concat(org.repositories.to_a)
          end
        end
      end

      # attr_accessor:
      def products
        @@components = Hash.new
        @@combined = Hash.new
        products = load_content['products'].clone
        products.each_with_index do |product, x|
          if product.class == Hash
            if product.fetch('combine', false)
              hash_combined(product)
            end
            if product.fetch('components', false)
              hash_components(product)
            end
            products[x] = product.keys.first
          end
        end
      end

      def combined
        @@combined
      end

      def components
        @@components
      end

      def organizations
        @@organizations
      end

      def all_repositories
        @@all_repositories
      end

      def supported_vcs
        @@SUPPORTED_VCS.select do |vcs|
          content.keys.map(&:downcase).include?(vcs)
        end
      end

      def content
        load_content
      end

      private

      def hash_components(product)
        @@components[product.keys.first] = product.fetch('components', nil)
      end

      def hash_combined(product)
        @@combined[product.keys.first] = product.fetch('combine', nil)
      end

      def is_valid?
        if load_content.nil? || load_content.empty?
          abort("Config empty or corrupted")
        elsif load_content['products'].nil? || load_content['products'].empty?
          abort("Config incomplete: No products found")
        end
        true
      end

      def init_vcs
        @@organizations = Hash.new
        @@all_repositories = Hash.new
        supported_vcs.each do |vcs|
          @@organizations[vcs] = Array.new
          @@all_repositories[vcs] = Array.new
        end
      end

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
