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
    @jenkins_jobs = Nailed::Config.jobs

    DB.tables.select{|s| s.to_s.include?('trends')}.each do |table|
      DB.run("CREATE TEMP VIEW IF NOT EXISTS #{table.to_s.concat("_view")} "\
             "AS SELECT * FROM #{table} WHERE date(time) > date('now', '-1 year')")
    end
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
        trends = DB[:bugtrends_view].select(:time, :open, :fixed)
          .where(product_name: item).naked.all
        filter(trends).each do |col|
          json << { time: col[:time].strftime("%Y-%m-%d %H:%M:%S"),
                    open: col[:open], fixed: col[:fixed] }
        end
      when :change
        trends = DB[:changetrends_view].select(:time, :open)
          .where(oname: item[0], rname: item[1]).naked.all
        filter(trends).each do |col|
          json << { time: col[:time].strftime("%Y-%m-%d %H:%M:%S"),
                    open: col[:open] }
        end
      when :allopenchanges
        table = "allchangetrends_view"
        origin = ""
        @supported_vcs.each do |vcs|
          origin.concat("LEFT JOIN (SELECT time as t_#{vcs}, open as #{vcs} " \
                        "FROM #{table} WHERE origin='#{vcs}') ON time=t_#{vcs} ")
        end
        trends = DB.fetch("SELECT time, #{@supported_vcs.join(', ')} " \
                          "FROM ((SELECT DISTINCT time FROM #{table}) " \
                          "#{origin})").naked.all
        filter(trends).each do |col|
          json << col.merge({time: col[:time].strftime("%Y-%m-%d %H:%M:%S")})
        end
      when :allbugs
        trends = DB[:allbugtrends_view].order_by(:time).naked.all
        filter(trends).each do |col|
          json << { time: col[:time].strftime("%Y-%m-%d %H:%M:%S"),
                    open: col[:open] }
        end
      when :l3
        trends = DB[:l3trends_view].naked.all
        filter(trends).each do |col|
          json << { time: col[:time].strftime("%Y-%m-%d %H:%M:%S"),
                    open: col[:open] }
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

    def filter(data, datapoints = 40)
        filtered = Hash.new
        num = data.length/datapoints
        data.first.keys.each do |key|
          filtered[key] = data.each_slice(num.zero? ? num.succ : num)
            .map{|slice| slice.map{|value| value[key].nil? ? 0 : value[key]}.max}
        end
        filtered.values.transpose.map{|value| Hash[filtered.keys.zip(value)]}
    end

    ### jenkins helpers ###

    # returns a formatted string with all build parameters for the popover
    def get_jenkins_build_parameters(job, build_number)
      all_build_parameters = Jenkinsparametervalue.where(
        jenkinsbuild_job: job,
        jenkinsbuild_number: build_number)

      description = Jenkinsbuild.where(
        number: build_number,
        job: job
      ).map(&:description)[0] || ""

      ret = ""
      all_build_parameters.each do |bp|
        ret += bp.jenkinsparameter_name + " = " + bp.value + "\n" unless bp.value.empty?
      end

      ret + "\nequal_builds:" + get_equal_builds(job, build_number).to_s +
        "\ndescription: " + description.split("/").to_s
    end

    # find equal jenkins builds
    def get_equal_builds(job, build_number)
      Jenkinsbuild.where(
        job: job,
        number: build_number
      ).map(&:equal_builds)[0].split(",").take(10)
    end

    # generates a view object for a specific build parameter within a job
    # TODO: Refactor function to execute faster (e.g. execute for all params combined)
    #       For now the data is just being cached for one hour.
    def get_jenkins_view_object(job, parameter)

      call = "#{__method__}-#{job}-#{parameter})".to_sym
      view_object = Nailed::Cache.get_cache(call, 3600)

      return view_object unless view_object.nil?

      view_object = {}
      all_parameters = Jenkinsparametervalue.where(
        jenkinsparameter_name: parameter,
        jenkinsparameter_job: job,
        jenkinsbuild_number: Jenkinsbuild.exclude(result: nil).select(:number)
        ).map(&:value).uniq.sort

      all_parameters.each do |parameter_name|
        view_object[parameter_name] = {}
        all_builds_with_parameter = Jenkinsparametervalue.where(
          jenkinsparameter_name: parameter,
          jenkinsparameter_job: job,
          value: parameter_name)
          .order(Sequel.desc(:jenkinsbuild_number)).limit(15)

        all_builds_with_parameter.each do |build|
          build_number = build.jenkinsbuild_number
          build_details = Jenkinsbuild.where(job: job, number: build_number)
          build_details.each do |build_detail|
            view_object[parameter_name][build_number] = {
              build_url: build_detail.url,
              build_result: build_detail.result,
              build_parameters: get_jenkins_build_parameters(job, build_number)
            }
          end
        end
      end

      Nailed::Cache.set_cache(call, view_object)
      view_object
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
  # CHANGES Routes
  #

  #
  # trends
  #
  changes_repos = Changerequest.order(Sequel.desc(:created_at)).all.map do |row|
    [row.oname, row.rname]
  end.uniq

  changes_repos.each do |repo|
    get "/json/changes/#{repo[0]}/#{repo[1]}/trend/open" do
      get_trends(:change, repo)
    end
  end

  # all open change requests
  get "/json/changes/trend/allopenchanges" do
    get_trends(:allopenchanges, nil)
  end

  #
  # donut
  #
  get "/json/changes/donut/allchanges" do
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
    get "/json/#{vcs}/allopenchanges" do
      Changerequest.where(state: "open", origin: vcs).naked.all.to_json
    end
  end

  # all open pull requests for repo
  Changerequest.select(:oname, :rname).distinct.where(state: "open").order(Sequel.desc(:created_at)).map do |repo|
    get "/json/changes/#{repo.oname}/#{repo.rname}/open" do
      Changerequest.where(
        state: "open",
        rname: repo.rname,
        oname: repo.oname).naked.all.to_json
    end
  end

  #
  # JENKINS Routes
  #

  Nailed::Config.jobs.each do |job|
    get "/jenkins/#{job}" do

      @job = job
      @view_object = {}
      blacklist = Nailed::Config.content["jenkins"]["blacklist"]["parameter"] || []
      all_parameters = Jenkinsparameter.where(job: job).map(&:name).sort_by(&:downcase)
      all_parameters.each do |parameter|
        next if blacklist.include? parameter
        @view_object[parameter] = get_jenkins_view_object(job, parameter)
      end

      haml :jenkins
    end
  end unless Nailed::Config.jobs.empty?

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
    Changerequest.select(:oname, :rname, :url).distinct.where(origin: vcs).order(Sequel.desc(:created_at)).all.map do |repo|
      get "/#{vcs}/#{repo.oname}/#{repo.rname}" do
        url = repo.url.rpartition("/").first

        @org = repo.oname
        @repo = repo.rname
        @url = url.concat(url.end_with?("s") ? "" : "s")

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
