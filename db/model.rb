require 'sequel'

db_path = ENV["DATABASE_URL"]
# if not set, use default:
db_path ||= File.join(File.expand_path(File.dirname(__FILE__)), "nailed_0.db")

DB = Sequel.connect("sqlite://#{db_path}")

### expects existing Database with appropriate tables
## Bugzilla specific tables
class Bugreport < Sequel::Model
end

class Bugtrend < Sequel::Model
end

class Allbugtrend < Sequel::Model
end

class L3trend < Sequel::Model
end

## GitHub specific tables
class Pullrequest < Sequel::Model
  many_to_one :repository
end

class Pulltrend < Sequel::Model
  many_to_one :repository
end

class Allpulltrend < Sequel::Model
end
