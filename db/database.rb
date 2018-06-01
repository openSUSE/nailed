require "sequel"

db_path = ENV["DATABASE_URL"]
# if not set, use default:
db_path ||= File.join(File.expand_path(File.dirname(__FILE__)), "nailed.db")

DB = Sequel.connect("sqlite://#{db_path}")

# BugZilla specific tables
class Product < Sequel::Model
  one_to_many :bugreports
  one_to_many :bugtrends
end

class Bugreport < Sequel::Model
  many_to_one :product
end

class Bugtrend < Sequel::Model
  many_to_one :product
end

class AllbugTrend < Sequel::Model
  table_name = "allbug_trends"
end

class L3Trend < Sequel::Model
end

# GitHub specific tables
class Organization < Sequel::Model
  one_to_many :repository
end

class Repository < Sequel::Model
  table_name = "repositories"
  many_to_one :organization
end

class Pullrequest < Sequel::Model
  many_to_one :repository
end

class Pulltrend < Sequel::Model
  many_to_one :repository
end

class AllpullTrend < Sequel::Model
end
