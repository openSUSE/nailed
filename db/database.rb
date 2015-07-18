require 'data_mapper'

# set all String properties to have a default length of 255
DataMapper::Property::String.length(666)

###                            ###
# setup the database connection  #
###                            ###

# BugZilla specific tables
class Product
  include DataMapper::Resource
  property :name, String, :required => true, :key => true

  has n, :bugreports
  has n, :bugtrends
end

class Bugreport
  include DataMapper::Resource
  property :bug_id, Integer, :required => true, :key => true
  property :summary, String
  property :status, String, :required => true
  property :is_open, Boolean, :required => true
  property :component, String
  property :severity, String
  property :priority, String
  property :whiteboard, String
  property :assigned_to, String
  property :creation_time, DateTime
  property :last_change_time, DateTime
  property :url, String

  belongs_to :product
end

class Bugtrend
  include DataMapper::Resource
  property :id, Serial, :key => true
  property :time, String
  property :open, Integer
  property :fixed, Integer

  belongs_to :product
end

class AllbugTrend
  include DataMapper::Resource
  property :id, Serial, :key => true
  property :time, String
  property :open, Integer
end

class L3Trend
  include DataMapper::Resource
  property :id, Serial, :key => true
  property :time, String
  property :open, Integer
end

# GitHub specific tables
class Organization
  include DataMapper::Resource
  property :oname, String, :required => true, :key => true

  has n, :repositories
end

class Repository
  include DataMapper::Resource
  property :rname, String, :required => true, :key => true, :unique_index => false

  belongs_to :organization, :required => false, :key => true
end

class Pullrequest
  include DataMapper::Resource
  property :id, Serial
  property :pr_number, Integer, :required => true
  property :title, String
  property :state, String
  property :url, String
  property :created_at, DateTime

  belongs_to :repository
end

class Pulltrend
  include DataMapper::Resource
  property :id, Serial, :key => true
  property :time, String
  property :open, Integer

  belongs_to :repository
end

class AllpullTrend
  include DataMapper::Resource
  property :id, Serial, :key => true
  property :time, String
  property :open, Integer
end

# TODO Jenkins specific tables

class JenkinsParameter
  include DataMapper::Resource
  property :name, String, :key => true
  property :job, String, :key => true
  property :type, String
  property :description, String
  property :default, String
end

class JenkinsBuild
  include DataMapper::Resource
  property :number, Integer, :key => true
  property :job, String, :key => true
  property :description, String
  property :url, String
  property :result, String
  property :built_on, String
  property :equal_builds, String
end

class JenkinsParameterValue
  include DataMapper::Resource
  property :id, Serial, :key => true
  property :value, String

  belongs_to :jenkins_parameter
  belongs_to :jenkins_build
end

DataMapper.finalize

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{File.join(File.expand_path(File.dirname(__FILE__)), 'nailed.db')}")
