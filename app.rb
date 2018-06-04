#!/usr/bin/env ruby

require "sinatra"
require "sprockets"
require "haml"
require "json"
require "time"
require_relative "lib/nailed"
require_relative "db/database"

class App < Sinatra::Application

  set :bind, "0.0.0.0"
  set :port, Nailed::Config["port"] || 4567
  theme = Nailed::Config["theme"] || "default"

  assets = Sprockets::Environment.new

  assets.append_path File.join(__dir__, "assets/stylesheets/")
  assets.append_path File.join(__dir__, "assets/javascript/")
  assets.append_path File.join(__dir__, "assets/images/")

  get "/assets/*" do
    env["PATH_INFO"].sub!("/assets", "")
    assets.call(env)
  end

  before do
    @title = Nailed::Config["title"] || "Dashboard"
    @products = Nailed::Config.products.map { |_p, v| v["versions"] }.flatten.compact
    @product_query = @products.join("&product=")
    @org_query = Nailed::Github.orgs.map { |o| o.prepend("user%3A") }.join("+")
    @colors = Nailed.get_colors
  end

  helpers do
    ### generic helpers

    def get_trends(action, item)
      json = []
      case action
      when :bug
        table = "bugtrends"
        sql_statement =
          if Bugtrend.count(product_name: item) > 20
            "SELECT (SELECT COUNT(0) " \
            "FROM #{table} t1 " \
            "WHERE t1.id <= t2.id " \
            "AND product_name = '#{item}') " \
            "AS tmp_id, time, open, fixed, product_name " \
            "FROM #{table} AS t2 " \
            "WHERE product_name = '#{item}' " \
            "AND (tmp_id % ((SELECT COUNT(*) " \
            "FROM #{table} " \
            "WHERE product_name = '#{item}')/20) = 0) " \
            "ORDER BY id"
          else
            "SELECT time, open, fixed " \
            "FROM #{table} " \
            "WHERE product_name = '#{item}'"
          end
        trends = Bugtrend.fetch(sql_statement)
        trends.each do |col|
          json << { time: col.time, open: col.open, fixed: col.fixed }
        end
      when :pull
        table = "pulltrends"
        sql_statement =
          if (Pulltrend.count(repository_organization_oname: item[0], repository_rname: item[1]) > 20)
            "SELECT (SELECT COUNT(0) " \
            "FROM #{table} t1 " \
            "WHERE t1.id <= t2.id AND repository_rname = '#{item[1]}' " \
            "AND repository_organization_oname = '#{item[0]}')" \
            "AS tmp_id, time, open, repository_rname " \
            "FROM #{table} AS t2 " \
            "WHERE repository_rname = '#{item[1]}' " \
            "AND repository_organization_oname = '#{item[0]}' " \
            "AND (tmp_id % ((SELECT COUNT(*) " \
            "FROM #{table} WHERE repository_rname = '#{item[1]}' " \
            "AND repository_organization_oname = '#{item[0]}')/20) = 0)" \
            "ORDER BY id"
          else
            "SELECT time, open " \
            "FROM #{table} " \
            "WHERE repository_rname = '#{item[1]}' " \
            "AND repository_organization_oname = '#{item[0]}'"
          end
        trends = Pulltrend.fetch(sql_statement)
        trends.each do |col|
          json << { time: col.time, open: col.open }
        end
      when :allpulls
        table = "allpull_trends"
        filter =
          if AllpullTrend.count > 20
            "WHERE (id % ((SELECT COUNT(*) " \
            "FROM #{table})/20) = 0) " \
            "OR (id = (SELECT MAX(id) FROM #{table}));"
          else
            ""
          end
        trends = AllbugTrend.fetch("SELECT * FROM #{table} #{filter}")
        trends.each do |col|
          json << { time: col.time, open: col.open }
        end
      when :allbugs
        table = "allbug_trends"
        sql_statement = "SELECT * " \
                        "FROM (SELECT * FROM #{table} ORDER BY time) " \
                        "GROUP BY date(time)"
        trends = AllbugTrend.fetch(sql_statement)
        trends.each do |col|
          json << { time: col.time, open: col.open }
        end
      when :l3
        table = "l3_trends"
        filter =
          if L3Trend.count > 20
            "WHERE (id % ((SELECT COUNT(*) FROM #{table})/20) = 0)"
          else
            ""
          end
        trends = L3Trend.fetch("SELECT * FROM #{table} #{filter}")
        trends.each do |col|
          json << { time: col.time, open: col.open }
        end
      end
      json.to_json
    end

    ### github helpers

    def get_github_repos
      Repository.all
    end
  end

  #
  # BUGZILLA Routes
  #

  #
  # bar
  #
  Nailed::Config.products.each do |_product, values|
    versions = values["versions"]
    versions.each do |version|
      get "/json/bugzilla/#{version.tr(" ", "_")}/bar/priority" do
        bugprio = []
        { "P0 - Crit Sit" => "p0",
          "P1 - Urgent"   => "p1",
          "P2 - High"     => "p2",
          "P3 - Medium"   => "p3",
          "P4 - Low"      => "p4",
          "P5 - None"     => "p5" }.each_pair do |key, val|
          bugprio << { "bugprio" => key, val => Bugreport.where(product_name: version, priority: key, is_open: 't').count }
        end
        bugprio.to_json
      end
    end unless versions.nil?
  end
  #
  # status
  #
  Nailed::Config.products.each do |_product, values|
    versions = values["versions"]
    versions.each do |version|
      get "/json/bugzilla/#{version.tr(" ", "_")}/bar/status" do
        bugstatus = []
        { "NEW"         => 's0',
          "CONFIRMED"   => 's1',
          "IN_PROGRESS" => 's2',
          "REOPENED"    => 's3' }.each_pair do |key, val|
          bugstatus << { "bugstatus" => key, val => Bugreport.where(product_name: version, status: key, is_open: 't').count }
        end
        bugstatus.to_json
      end
    end unless versions.nil?
  end

  #
  # trends
  #
  Nailed::Config.products.each do |_product, values|
    versions = values["versions"]
    versions.each do |version|
      get "/json/bugzilla/#{version.tr(" ", "_")}/trend/open" do
        get_trends(:bug, version)
      end
    end unless versions.nil?
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
  Nailed::Config.products.each do |_product, values|
    versions = values["versions"]
    versions.each do |version|
      get "/json/bugzilla/#{version.tr(" ", "_")}/donut/component" do
        top5_components = []
        sql_statement = "SELECT component AS label, " \
                        "COUNT(component) AS value " \
                        "FROM bugreports " \
                        "WHERE product_name = '#{version}' " \
                        "AND is_open = 't' " \
                        "GROUP BY component " \
                        "ORDER BY COUNT(component) " \
                        "DESC LIMIT 5"
        components = Repository.fetch(sql_statement).all
        components.each do |bar|
          top5_components << { label: bar[:label], value: bar[:value] }
        end
        component_labels = top5_components.map { |a| a.values[0] }
        component_values = top5_components.map { |a| a.values[1] }
        top5_components.to_json
      end
    end unless versions.nil?
  end

  get "/json/bugzilla/donut/allbugs" do
    bugtop = []
    Nailed::Config.products.each do |_product, values|
      versions = values["versions"]
      versions.each do |version|
        open = Bugreport.where(product_name: version, is_open: 't').count
        bugtop << { label: version, value: open } unless open == 0
      end unless versions.nil?
    end
    bugtop.to_json
  end

  #
  # tables
  #

  # allopen
  get "/json/bugzilla/allopen" do
    Bugreport.where(is_open: 't').naked.all.to_json
  end

  # allopenwithoutl3
  get "/json/bugzilla/allopenwithoutl3" do
    (Bugreport.where(is_open: 't').naked.all - Bugreport.where(is_open: 't').where(Sequel.like(:whiteboard, "%openL3%")).naked.all).to_json
  end

  # allopenl3
  get "/json/bugzilla/allopenl3" do
    Bugreport.where(is_open: 't').where(Sequel.like(:whiteboard, "%openL3%")).naked.all.to_json
  end

  # product -> openwithoutl3
  Nailed::Config.products.each do |_product, values|
    versions = values["versions"]
    versions.each do |version|
      get "/json/bugzilla/#{version.tr(" ", "_")}/openwithoutl3" do
        open_bugs = Bugreport.where(is_open: 't', product_name: version).naked.all
        open_l3_bugs = Bugreport.where(is_open: 't', product_name: version).where(Sequel.like(:whiteboard, "%openL3%")).naked.all
        (open_bugs - open_l3_bugs).to_json
       # (Bugreport.where(is_open: 't', product_name: version).naked.all - Bugreport.where(Sequel.like(:whiteboard => "%openL3%").where(is_open: 't', product_name: version).naked.all)).to_json
      end
    end unless versions.nil?
  end

  # product -> openl3
  Nailed::Config.products.each do |_product, values|
    versions = values["versions"]
    versions.each do |version|
      get "/json/bugzilla/#{version.tr(" ", "_")}/openl3" do
        Bugreport.where(is_open: 't', product_name: version).where(Sequel.like(:whiteboard, "%openL3%")).naked.all.to_json
      end
    end unless versions.nil?
  end

  #
  # GITHUB Routes
  #

  #
  # trends
  #
  github_repos = Pullrequest.reverse(:created_at).all.map do |row|
    [row.repository_organization_oname, row.repository_rname]
  end.uniq

  github_repos.each do |repo|
    get "/json/github/#{repo[0]}/#{repo[1]}/trend/open" do
      get_trends(:pull, repo)
    end
  end

  # all open pull requests
  get "/json/github/trend/allpulls" do
    get_trends(:allpulls, nil)
  end

  #
  # donut
  #
  get "/json/github/donut/allpulls" do
    pulltop = []
    open_pulls = Pullrequest.where(state: "open")
    grouped_pulls = open_pulls.group_and_count(:repository_rname,
                                               :repository_organization_oname).all
    grouped_pulls.each do |pull|
      pulltop << { label: "#{pull.repository_organization_oname}/#{pull.repository_rname}",
                   value: pull[:count] }
    end
    pulltop.to_json
  end

  #
  # tables
  #

  # allopenpulls
  get "/json/github/allopenpulls" do
    Pullrequest.where(state: "open").naked.all.to_json
  end

  # all open pull requests for repo
  github_repos = Pullrequest.where(state: "open").reverse(:created_at).map do |row|
    [row.repository_organization_oname, row.repository_rname]
  end.uniq

  github_repos.each do |repo|
    get "/json/github/#{repo[0]}/#{repo[1]}/open" do
      Pullrequest.where(
        state:                         "open",
        repository_rname:              repo[1],
        repository_organization_oname: repo[0]).naked.all.to_json
    end
  end

  #
  # MAIN Routes
  #

  get "/" do
    @github_repos = get_github_repos

    haml :index
  end

  Nailed::Config.products.each do |_product, values|
    versions = values["versions"]
    versions.each do |version|
      get "/#{version.tr(" ", "_")}/bugzilla" do
        @github_repos = get_github_repos

        @product = version
        @product_ = version.tr(" ", "_")
        @top5 = values["qe"]

        haml :bugzilla
      end
    end unless versions.nil?
  end

  github_repos = Pullrequest.reverse(:created_at).all.map do |row|
    [row.repository_organization_oname, row.repository_rname]
  end.uniq

  github_repos.each do |repo|
    get "/github/#{repo[0]}/#{repo[1]}" do
      @github_repos = get_github_repos

      @repo = repo[1]
      @org = repo[0]
      @github_url_all_pulls = "https://github.com/#{@org}/#{repo}/pulls"

      haml :github
    end
  end

  get "/json/help" do
    routes = []
    App.routes["GET"].each do |route|
      routes << { route: route[0].to_s }
    end
    routes.uniq.to_json
  end

  get "/help" do
    @github_repos = get_github_repos

    haml :help
  end

  run! if app_file == $PROGRAM_NAME
end
