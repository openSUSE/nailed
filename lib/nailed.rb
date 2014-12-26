require 'logger'
require 'yaml'
require "octokit"
require "bicho"
require  File.join(File.expand_path("..", File.dirname(__FILE__)),"db","database")

module Nailed
  LOGGER = Logger.new(File.join(File.expand_path("..", File.dirname(__FILE__)),"log","nailed.log"))
  CONFIG_FILE =  File.join(File.expand_path("..", File.dirname(__FILE__)),"config","products.yml")
  PRODUCTS = YAML.load_file(CONFIG_FILE)

  class Bugzilla
    def initialize
      Bicho.client = Bicho::Client.new('https://bugzilla.novell.com')
    end

    def get_bugs(product)
      Bicho::Bug.where(:product => product).each do |bug|
        attributes = {
          :bug_id => bug.id,
          :summary => bug.summary,
          :status => bug.status,
          :is_open => bug.is_open,
          :product_name => bug.product,
          :component => bug.component,
          :severity => bug.severity,
          :priority => bug.priority,
          :whiteboard => bug.whiteboard,
          :assigned_to => bug.assigned_to,
          :creation_time => "#{bug.creation_time.to_date}T#{bug.creation_time.hour}:#{bug.creation_time.min}:#{bug.creation_time.sec}+00:00",
          :last_change_time => "#{bug.last_change_time.to_date}T#{bug.last_change_time.hour}:#{bug.last_change_time.min}:#{bug.last_change_time.sec}+00:00",
          :url => bug.url.gsub(/novell.com\//,'suse.com/show_bug.cgi?id=')
        }

        db_handler = (Bugreport.get(bug.id) || Bugreport.new).update(attributes)
      end
    end

    def get_product(product)
      prod = Product.get(product)
      abort "No such product in the database" if prod.nil?
    end

    def add_product(product)
      if Nailed.config(:get, "products", product)
        Nailed.config(:add, "products", product)
        db_handler = Product.first_or_create(:name => product)
        Nailed.log("info", "#{product} added to the database")
      else
        Nailed.log("error", "#{product} is already in the database")
        abort "#{product} is already in the database"
      end

      Nailed.save_state(db_handler)
    end

    def remove_product(product)
      Nailed.config(:delete, "products", product)
      Bugreport.all(:product_name => product).destroy
      Bugtrend.all(:product_name => product).destroy
      Product.get(product).destroy
      Nailed.log("info", "#{product} removed from the database")
    end

    def write_bug_trends(product)
      open = Bugreport.count(:is_open => true, :product_name => product)
      fixed = Bugreport.count(:status => "VERIFIED", :product_name => product) + \
              Bugreport.count(:status => "RESOLVED", :product_name => product)
      db_handler = Bugtrend.first_or_create(
                   :time => Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                   :open => open,
                   :fixed => fixed,
                   :product_name => product
                   )

      Nailed.save_state(db_handler)
    end

    def write_l3_trends
      open = Bugreport.count(:whiteboard.like => "%openL3%", :is_open => true)
      db_handler = L3Trend.first_or_create(
                   :time => Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                   :open => open
                   )

      Nailed.save_state(db_handler)
    end
  end

  class Github
    def initialize
      @client = Octokit::Client.new(:netrc => true)
    end

    def get_components(repo)
      repos = @client.org_repos(repo)
      components = repos.map(&:name)
      components
    end

    def fill_db_after_migration
      barclamps = get_components("crowbar")
      barclamps.each do |bc_name|
        Nailed.config(:add, "crowbar", bc_name)
        db_handler = Crowbar.first_or_create(:component => bc_name)

        Nailed.save_state(db_handler)
      end
    end

    def get_open_pulls(crowbar_components)
      crowbar_components.each do |comp|
        pulls = @client.pull_requests("crowbar/#{comp.component}")
        pulls.each do |pr|
          db_handler = Pullrequest.first_or_create(
                       :pr_number => pr.number,
                       :title => pr.title,
                       :state => pr.state,
                       :url => pr.html_url,
                       :created_at => pr.created_at,
                       :crowbar_component => comp.component
                       )

          Nailed.save_state(db_handler)
        end unless pulls.empty?
        write_pull_trends(comp.component)
      end
    end

    def update_pull_states
      Pullrequest.all.each do |db_pull|
        number = db_pull.pr_number
        component = db_pull.crowbar_component
        github_pull = @client.pull_request("crowbar/#{component}", number)
        if github_pull.state == "closed"
          db_pull.destroy
        end
      end
    end

    def write_pull_trends(component)
      open = Pullrequest.count(:crowbar_component => component)
      db_handler = Pulltrend.first_or_create(
                   :time => Time.new.strftime("%Y-%m-%d %H:%M:%S"),
                   :open => open,
                   :crowbar_component => component
                   )

      Nailed.save_state(db_handler)
    end
  end

  def Nailed.log(level,msg)
    if level == "error"
      Nailed::LOGGER.error(msg)
    else
      Nailed::LOGGER.info(msg)
    end
  end

  def Nailed.config(action,section,item)
    case action
    when :add
      if Nailed::PRODUCTS[section].first.nil?
        Nailed::PRODUCTS[section] << item
        Nailed::PRODUCTS[section].compact!
      else
        Nailed::PRODUCTS[section] << item
      end
    when :delete
      Nailed::PRODUCTS[section].delete(item)
    when :cleanup
      Nailed::PRODUCTS[section].clear
      Nailed::PRODUCTS[section] << nil
    when :get
      return false if Nailed::PRODUCTS[section].include? item
    end
    File.open(Nailed::CONFIG_FILE, "w") {|f| f.write Nailed::PRODUCTS.to_yaml}
  end

  def Nailed.save_state(db_handler)
    unless db_handler.save
      log("error", db_handler.errors.inspect)
    end
  end
end
