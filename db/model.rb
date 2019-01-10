require 'sequel'

db_path = ENV["DATABASE_URL"]
# if not set, use default:
db_path ||= File.join(File.expand_path(File.dirname(__FILE__)),
                      "nailed_#{Nailed::VERSION}.db")

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

## GitHub/GitLab specific tables
class Changerequest < Sequel::Model
  many_to_one :repository
end

class Changetrend < Sequel::Model
  many_to_one :repository
end

class Allchangetrend < Sequel::Model
end
