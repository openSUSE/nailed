#!/usr/bin/env ruby

require "sinatra/base"
require "sprockets"
require "haml"
require "json"
require "time"
require_relative "lib/nailed"
require_relative "db/model"

class App < Sinatra::Base

  Nailed::Config.parse_config
  Nailed::Cache.initialize

  enable :logging
  set :bind, "0.0.0.0"
  set :port, Nailed::Config.content["port"] || 4567
  theme = Nailed::Config.content["theme"] || "default"

  before do
    @title = Nailed::Config.content["title"] || "Dashboard"
    @bugzilla = Nailed::Config.content.fetch("bugzilla")
    @products = Nailed::Config.products
    @product_query = @products.join("&product=")
    @orgs = Nailed::Config.organizations["github"]
    @org_query = @orgs.map { |o| o.name.dup.prepend("user%3A") }.join("+") unless @orgs.nil?
    @supported_vcs = Nailed::Config.supported_vcs
    @changes_repos = get_repos
    @colors = Nailed.get_colors
  end

  # sprockets asset management:
  assets = Sprockets::Environment.new

  assets.append_path File.join(__dir__, "assets/stylesheets/")
  assets.append_path File.join(__dir__, "assets/javascript/")
  assets.append_path File.join(__dir__, "assets/images/")
  assets.append_path File.join(__dir__, "assets/fonts/")

  get "/assets/*" do
    env["PATH_INFO"].sub!("/assets", "")
    assets.call(env)
  end

  get "/fonts/*" do
    env["PATH_INFO"].sub!("/fonts", "")
    assets.call(env)
  end

  # generic helpers:
  helpers do

    def get_trends(action, item)
      call = "#{__method__}-#{action}-#{item})".to_sym
      json = Nailed::Cache.get_cache(call)

      return json unless json.nil?

      json = []
      case action
      when :bug
        table = "bugtrends"
        sql_statement =
          if Bugtrend.where(product_name: item).count > 40
            "SELECT (SELECT COUNT(0) " \
            "FROM #{table} t1 " \
            "WHERE t1.rowid <= t2.rowid " \
            "AND product_name = '#{item}') " \
            "AS tmp_id, time, open, fixed, product_name " \
            "FROM #{table} AS t2 " \
            "WHERE product_name = '#{item}' " \
            "AND (tmp_id % ((SELECT COUNT(*) " \
            "FROM #{table} " \
            "WHERE product_name = '#{item}')/40) = 0) " \
            "ORDER BY time"
          else
            "SELECT time, open, fixed " \
            "FROM #{table} " \
            "WHERE product_name = '#{item}'"
          end
        trends = Bugtrend.fetch(sql_statement)
        trends.each do |col|
          json << { time: col.time.strftime("%Y-%m-%d %H:%M:%S"),
                    open: col.open, fixed: col.fixed }
        end
      when :change
        table = "changetrends"
        sql_statement =
          if (Changetrend.where(oname: item[0], rname: item[1]).count > 20)
            "SELECT (SELECT COUNT(0) " \
            "FROM #{table} t1 " \
            "WHERE t1.rowid <= t2.rowid AND rname = '#{item[1]}' " \
            "AND oname = '#{item[0]}')" \
            "AS tmp_id, time, open, rname " \
            "FROM #{table} AS t2 " \
            "WHERE rname = '#{item[1]}' " \
            "AND oname = '#{item[0]}' " \
            "AND (tmp_id % ((SELECT COUNT(*) " \
            "FROM #{table} WHERE rname = '#{item[1]}' " \
            "AND oname = '#{item[0]}')/20) = 0)" \
            "ORDER BY time"
          else
            "SELECT time, open " \
            "FROM #{table} " \
            "WHERE rname = '#{item[1]}' " \
            "AND oname = '#{item[0]}'"
          end
        trends = Changetrend.fetch(sql_statement)
        trends.each do |col|
          json << { time: col.time.strftime("%Y-%m-%d %H:%M:%S"),
                    open: col.open }
        end
      when :allopenchanges
        table = "allchangetrends"
        origin = ""
        filter =
          if Allchangetrend.count > 20
            # we only want roughly 20 data points and the newest data point:
            "WHERE (rowid % ((SELECT COUNT(*) " \
            "FROM #{table})/20) = 0) " \
            "OR (time = (SELECT MAX(time) FROM #{table}))"
          else
            ""
          end
        @supported_vcs.each do |vcs|
          origin.concat("LEFT JOIN (SELECT time as t_#{vcs}, open as #{vcs} " \
                        "FROM #{table} WHERE origin='#{vcs}') ON time=t_#{vcs} ")
        end
        trends = Allchangetrend.fetch("SELECT time, #{@supported_vcs.join(', ')} " \
                                      "FROM ((SELECT DISTINCT time FROM #{table} " \
                                      "#{filter}) #{origin})")
        trends.each do |col|
          json << col.values.merge({time: col.time.strftime("%Y-%m-%d %H:%M:%S")})
        end
      when :allbugs
        table = "allbugtrends"
        sql_statement = "SELECT * " \
                        "FROM (SELECT * FROM #{table} ORDER BY time) " \
                        "GROUP BY date(time)"
        trends = Allbugtrend.fetch(sql_statement)
        trends.each do |col|
          json << { time: col.time.strftime("%Y-%m-%d %H:%M:%S"),
                    open: col.open }
        end
      when :l3
        table = "l3trends"
        filter =
          if L3trend.count > 20
            # we only want roughly 20 data points or the newest data point:
            "WHERE (rowid % ((SELECT COUNT(*) FROM #{table})/20) = 0)" \
            "OR (time = (SELECT MAX(time) FROM #{table}));"
          else
            ""
          end
        trends = L3trend.fetch("SELECT * FROM #{table} #{filter}")
        trends.each do |col|
          json << { time: col.time.strftime("%Y-%m-%d %H:%M:%S"),
                    open: col.open }
        end
      end

      json = json.to_json
      Nailed::Cache.set_cache(call, json)

      return json
    end

    # Receives a product and checks for given components. 
    # If there is none the label becomes the name of the product.
    # If there is one '/$components' is added to the products name.
    # If there is more than one component '/subset' is added.
    def get_label(product)
      components = Nailed::Config.components[product]
      label = components.nil? ? product : product + "/#{components.length > 1 ? 'subset' : components.fetch(0)}"
    end

    def get_repos
      Hash[ @supported_vcs.collect {
        |vcs| [vcs, Changerequest.select(:oname, :rname).
               distinct.where(origin: vcs).naked.map(&:values)]
      }]
    end
  end

  #
  # BUGZILLA Routes
  #

  #
  # bar
  #
  Nailed::Config.products.each do |product|
    get "/json/bugzilla/#{product.tr(" ", "_")}/bar/priority" do
      bugprio = []
      { "P0 - Crit Sit" => "p0",
        "P1 - Urgent"   => "p1",
        "P2 - High"     => "p2",
        "P3 - Medium"   => "p3",
        "P4 - Low"      => "p4",
        "P5 - None"     => "p5" }.each_pair do |key, val|
        bugprio << { "bugprio" => key, val => Bugreport.where(product_name: product, priority: key, is_open: true).count }
      end
      bugprio.to_json
    end
  end
  #
  # status
  #
  Nailed::Config.products.each do |product|
    get "/json/bugzilla/#{product.tr(" ", "_")}/bar/status" do
      bugstatus = []
      { "NEW"         => 's0',
        "CONFIRMED"   => 's1',
        "IN_PROGRESS" => 's2',
        "REOPENED"    => 's3' }.each_pair do |key, val|
        bugstatus << { "bugstatus" => key,
                       val => Bugreport.where(
                         product_name: product,
                         status: key,
                         is_open: true).count }
      end
      bugstatus.to_json
    end
  end

  #
  # trends
  #
  Nailed::Config.products.each do |product|
    get "/json/bugzilla/#{product.tr(" ", "_")}/trend/open" do
      get_trends(:bug, product)
    end
  end

  get "/json/bugzilla/trend/allopenl3" do
    get_trends(:l3, nil)
  end

  get "/json/bugzilla/trend/allbugs" do
    get_trends(:allbugs, nil)
  end

  #
  # donut
  #
  Nailed::Config.products.each do |product|
    get "/json/bugzilla/#{product.tr(" ", "_")}/donut/component" do
      top5_components = []
      top_components = Bugreport
                         .select(:component, :is_open)
                         .where(is_open: true, product_name: product)
                         .group_and_count(:component)
                         .order(Sequel.desc(:count))
                         .limit(5).all
      top_components.each do |component|
        top5_components << { label: component.component, value: component[:count] }
      end
      top5_components.to_json
    end
  end

  get "/json/bugzilla/donut/allbugs" do
    bugtop = []
      Nailed::Config.products.each do |product|
        open = Bugreport.where(product_name: product, is_open: true).count
        bugtop << { label: get_label(product), value: open } unless open == 0
      end
    bugtop.to_json
  end

  #
  # tables
  #

  # allopen
  get "/json/bugzilla/allopen" do
    Bugreport.where(is_open: true).naked.all.to_json
  end

  # allopenwithoutl3
  get "/json/bugzilla/allopenwithoutl3" do
    (Bugreport.where(is_open: true).naked.all - Bugreport.where(is_open: true).where(Sequel.like(:whiteboard, "%openL3%")).naked.all).to_json
  end

  # allopenl3
  get "/json/bugzilla/allopenl3" do
    Bugreport.where(is_open: true).where(Sequel.like(:whiteboard, "%openL3%")).naked.all.to_json
  end

  # product -> openwithoutl3
  Nailed::Config.products.each do |product|
    get "/json/bugzilla/#{product.tr(" ", "_")}/openwithoutl3" do
      open_bugs = Bugreport.where(is_open: true,
                                  product_name: product).naked.all
      open_l3_bugs = Bugreport
                       .where(is_open: true,
                              product_name: product)
                       .where(Sequel.like(:whiteboard, "%openL3%")).naked.all
      (open_bugs - open_l3_bugs).to_json
    end
  end

  # product -> openl3
    Nailed::Config.products.each do |product|
      get "/json/bugzilla/#{product.tr(" ", "_")}/openl3" do
        Bugreport
          .where(is_open: true,
                 product_name: product)
          .where(Sequel.like(:whiteboard, "%openL3%")).naked.all.to_json
      end
    end

  #
  # GITHUB Routes
  #

  #
  # trends
  #
  changes_repos = Changerequest.order(Sequel.desc(:created_at)).all.map do |row|
    [row.oname, row.rname]
  end.uniq

  changes_repos.each do |repo|
    get "/json/github/#{repo[0]}/#{repo[1]}/trend/open" do
      get_trends(:change, repo)
    end
  end

  # all open change requests
  get "/json/github/trend/allpulls" do
    get_trends(:allopenchanges, nil)
  end

  #
  # donut
  #
  get "/json/github/donut/allpulls" do
    Changerequest.where(state: "open", origin: @supported_vcs)
      .group_and_count(:rname, :oname, :origin).all.map {
      |change| { label: "#{change.oname}/#{change.rname}",
                 value: change[:count],
                origin: change.origin }
    }.to_json
  end

  #
  # tables
  #

  # allopenchanges
  Nailed::Config.supported_vcs.each do |vcs|
    get "/json/github/allopenpulls" do
      Changerequest.where(state: "open", origin: vcs).naked.all.to_json
    end
  end

  # all open pull requests for repo
  Changerequest.select(:oname, :rname).distinct.where(state: "open").order(Sequel.desc(:created_at)).map do |repo|
    get "/json/github/#{repo.oname}/#{repo.rname}/open" do
      Changerequest.where(
        state: "open",
        rname: repo.rname,
        oname: repo.oname).naked.all.to_json
    end
  end

  #
  # MAIN Routes
  #

  get "/" do
    haml :index
  end

  Nailed::Config.products.each do |product|
    get "/#{product.tr(" ", "_")}/bugzilla" do
      @product = get_label(product)
      @product_ = product.tr(" ", "_")

      haml :bugzilla
    end
  end

  Nailed::Config.supported_vcs.each do |vcs|
    Changerequest.select(:oname, :rname).distinct.where(origin: vcs).order(Sequel.desc(:created_at)).all.map do |repo|
      get "/github/#{repo.oname}/#{repo.rname}" do
        @org = repo.oname
        @repo = repo.rname
        @github_url_all_pulls = "https://github.com/#{@org}/#{repo}/pulls"

        haml :changes
      end
    end
  end

  get "/json/help" do
    routes = []
    App.routes["GET"].each do |route|
      # avoids drawing asset routes:
      if route[0].to_s.include? '*'
        next
      end
      routes << { route: route[0].to_s }
    end
    routes.uniq.to_json
  end

  get "/help" do
    haml :help
  end

  run! if app_file == $PROGRAM_NAME
end
