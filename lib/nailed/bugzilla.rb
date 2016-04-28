module Nailed
  class Bugzilla
    def initialize
      Bicho.client = Bicho::Client.new(Nailed::Config["bugzilla"]["url"])
    end

    def get_bugs
      Nailed::Config.products.each do |product,values|
        values["versions"].each do |version|
          Nailed.logger.info("#{__method__}: Fetching bugs for #{version}")
          begin
            Bicho::Bug.where(product: version).each do |bug|
              attributes = {
                bug_id: bug.id,
                summary: bug.summary,
                status: bug.status,
                is_open: bug.is_open,
                product_name: bug.product,
                component: bug.component,
                severity: bug.severity,
                priority: bug.priority,
                whiteboard: bug.whiteboard,
                assigned_to: bug.assigned_to,
                creation_time: "#{bug.creation_time.to_date}T#{bug.creation_time.hour}:#{bug.creation_time.min}:#{bug.creation_time.sec}+00:00",
                last_change_time: "#{bug.last_change_time.to_date}T#{bug.last_change_time.hour}:#{bug.last_change_time.min}:#{bug.last_change_time.sec}+00:00",
                url: bug.url.gsub(/novell.com\//,"suse.com/show_bug.cgi?id=")
              }

              db_handler = (Bugreport.get(bug.id) || Bugreport.new).update(attributes)
              Nailed.logger.info("#{__method__}: Saved #{attributes.inspect}")
            end
          rescue
            Nailed.logger.error("Could not fetch Bugs for #{version}.")
          end
        end unless values["versions"].nil?
      end
    end

    def write_bug_trends
      Nailed::Config.products.each do |product,values|
        values["versions"].each do |version|
          Nailed.logger.info("#{__method__}: Writing bug trends for #{version}")
          open = Bugreport.count(is_open: true, product_name: version)
          fixed = Bugreport.count(status: "VERIFIED", product_name: version) + \
                  Bugreport.count(status: "RESOLVED", product_name: version)
          attributes = {time: Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                        open: open,
                        fixed: fixed,
                        product_name: version}

          db_handler = Bugtrend.first_or_create(attributes)

          Nailed.save_state(db_handler)
          Nailed.logger.info("#{__method__}: Saved #{attributes.inspect}")
        end unless values["versions"].nil?
      end
    end

    def write_allbug_trends
      Nailed.logger.info("#{__method__}: Aggregating all bug trends for all products")
      open = Bugreport.count(is_open: true)

      attributes = {time: Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                    open: open}

      db_handler = AllbugTrend.first_or_create(attributes)

      Nailed.save_state(db_handler)
      Nailed.logger.info("#{__method__}: Saved #{attributes.inspect}")
    end

    def write_l3_trends
      open = 0
      Nailed::Config.products.each do |product,values|
        values["versions"].each do |version|
          Nailed.logger.info("#{__method__}: Aggregating l3 trends for #{version}")
          open += Bugreport.count(:product_name => version, :whiteboard.like => "%openL3%", :is_open => true)
        end unless values["versions"].nil?
      end
      attributes = {time: Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                    open: open}

      db_handler = L3Trend.first_or_create(attributes)

      Nailed.save_state(db_handler)
      Nailed.logger.info("#{__method__}: Saved #{attributes.inspect}")
    end
  end
end
