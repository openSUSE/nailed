#TODO: since no new migration yet exist
require 'sequel'

# current migration files:
# nothing to migrate yet
#require_relative 'migrations/alter_db_0'

def migrateDB
  begin
    #path_to_db, db_id = find_db
  rescue NoDBException => e
    puts "[ERROR] Can't find Database"
    puts "If you want to create a Database, run: "
    puts "nailed --new"
  end
  #TODO: run migration scripts
end

def find_db
  #TODO
end
