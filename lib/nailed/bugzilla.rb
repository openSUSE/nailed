module Nailed
  class Bugzilla
    def initialize
      Bicho.client = Bicho::Client.new(Nailed::Config["bugzilla"]["url"])
    end

    def get_bugs
      Nailed::Config.products.each do |_product, values|
        values["versions"].each do |version|
          Nailed.logger.info("#{__method__}: Fetching bugs for #{version}")
          begin
            Bicho::Bug.where(product: version).each do |bug|
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
            Nailed.logger.error("Could not fetch Bugs for #{version}:\n#{e}")
          end
        end unless values["versions"].nil?
      end
    end

    def write_bug_trends
      Nailed::Config.products.each do |_product, values|
        values["versions"].each do |version|
          Nailed.logger.info("#{__method__}: Writing bug trends for #{version}")
          open = Bugreport.where(is_open: true, product_name: version).count
          fixed = Bugreport.where(status: "VERIFIED", product_name: version).count + \
            Bugreport.where(status: "RESOLVED", product_name: version).count
          attributes = { time:         Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                         open:         open,
                         fixed:        fixed,
                         product_name: version }

          begin
            DB[:bugtrends].insert(attributes)
          rescue Exception => e
            Nailed.logger.error("Could not write bug trend for #{version}:\n#{e}")
          end

          Nailed.logger.debug("#{__method__}: Saved #{attributes.inspect}")
        end unless values["versions"].nil?
      end
    end

    def write_allbug_trends
      Nailed.logger.info("#{__method__}: Aggregating all bug trends for all products")
      open = Bugreport.where(is_open: true).count

      attributes = { time: Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                     open: open }

      begin
        DB[:allbug_trends].insert(attributes)
      rescue Exception => e
        Nailed.logger.error("Could not write allbug trend:\n#{e}")
      end

      Nailed.logger.debug("#{__method__}: Saved #{attributes.inspect}")
    end

    def write_l3_trends
      open = 0
      Nailed::Config.products.each do |_product, values|
        values["versions"].each do |version|
          Nailed.logger.info("#{__method__}: Aggregating l3 trends for #{version}")
          open += Bugreport.where(product_name: version, is_open: true ).where(Sequel.like(:whiteboard, "%openL3%")).count
        end unless values["versions"].nil?
      end
      attributes = { time: Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                     open: open }

      begin
        DB[:l3_trends].insert(attributes)
      rescue Exception => e
        Nailed.logger.error("Could not write l3 trend:\n#{e}")
      end

      Nailed.logger.debug("#{__method__}: Saved #{attributes.inspect}")
    end
  end
end
