require 'bicho'

require_relative "./config"
require_relative "../../db/model"

module Nailed
  class Bugzilla
    def initialize
      Nailed::Config.parse_config
      Bicho.client = Bicho::Client.new(Nailed::Config.content["bugzilla"])
      @products = Nailed::Config.products.collect do |x|
        Nailed::Config.combined.fetch(x, x)
      end.flatten
    end

    def get_bugs
      @products.each do |product|
        Nailed.logger.info("#{__method__}: Fetching bugs for #{product}")
        components = Nailed::Config.components[product]
        query = components.nil? ? {product: product} : {product: product, component: components}
        begin
          retries ||= 0
          Bicho::Bug.where(query).each do |bug|
            attributes = {
              bug_id:           bug.id,
              summary:          bug.summary,
              status:           bug.status,
              is_open:          bug.is_open,
              product_name:     bug.product,
              component:        bug.component,
              severity:         bug.severity,
              priority:         bug.priority,
              whiteboard:       bug.whiteboard,
              assigned_to:      bug.assigned_to,
              creation_time:    "#{bug.creation_time.to_date}T#{bug.creation_time.hour}:#{bug.creation_time.min}:#{bug.creation_time.sec}+00:00",
              last_change_time: "#{bug.last_change_time.to_date}T#{bug.last_change_time.hour}:#{bug.last_change_time.min}:#{bug.last_change_time.sec}+00:00",
              fetched_at:       Time.now,
              url:              bug.url.gsub(/novell.com\//, "suse.com/show_bug.cgi?id=")
            }

            attributes[:requestee] = bug.flags.collect do |flag|
              next unless flag["name"] == "needinfo"
              flag["requestee"]
            end.compact.join(", ")

            DB[:bugreports].insert_conflict(:replace).insert(attributes)

            Nailed.logger.debug("#{__method__}: Saved #{attributes.inspect}")
          end
        rescue Exception => e
          retry if (retries += 1) < 2
          Nailed.logger.error("Could not fetch Bugs for #{product}:\n#{e}")
        end
      end
    end

    def write_bugtrends
      @products.each do |product|
        Nailed.logger.info("#{__method__}: Writing bug trends for #{product}")
        open = Bugreport.where(is_open: true, product_name: product).count
        fixed = Bugreport.where(status: "VERIFIED", product_name: product).count + \
                Bugreport.where(status: "RESOLVED", product_name: product).count
        attributes = { time:         Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                       open:         open,
                       fixed:        fixed,
                       product_name: product}

        begin
          DB[:bugtrends].insert(attributes)
        rescue Exception => e
          Nailed.logger.error("Could not write bug trend for #{product}:\n#{e}")
        end

        Nailed.logger.debug("#{__method__}: Saved #{attributes.inspect}")
      end
    end

    def write_allbugtrends
      Nailed.logger.info("#{__method__}: Aggregating all bug trends for all products")
      open = Bugreport.where(is_open: true).count

      attributes = { time: Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                     open: open }

      begin
        DB[:allbugtrends].insert(attributes)
      rescue Exception => e
        Nailed.logger.error("Could not write allbug trend:\n#{e}")
      end

      Nailed.logger.debug("#{__method__}: Saved #{attributes.inspect}")
    end

    def write_l3trends
      open = 0
      @products.each do |product|
        Nailed.logger.info("#{__method__}: Aggregating l3 trends for #{product}")
        open += Bugreport
                  .where(product_name: product,
                         is_open: true )
                  .where(Sequel.like(:whiteboard, "%openL3%")).count
      end
      attributes = { time: Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                     open: open }

      begin
        DB[:l3trends].insert(attributes)
      rescue Exception => e
        Nailed.logger.error("Could not write l3 trend:\n#{e}")
      end

      Nailed.logger.debug("#{__method__}: Saved #{attributes.inspect}")
    end

    def remove_stale_bugs
      Bugreport.select(:bug_id, :fetched_at).each do |bug|
        if (Time.now - bug.fetched_at > 86400) # stale for 1 day
          begin
            bug.destroy
            Nailed.logger.info("#{__method__}: bug_id: ##{bug.bug_id}")
          rescue Exception => e
            Nailed.logger.error("#{__method__}: Can't remove bug ##{bug.bug_id}: #{e}")
          end
        end
      end
    end
  end
end
