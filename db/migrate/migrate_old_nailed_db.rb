#!/usr/bin/ruby

require 'sequel'
require_relative '../schema'

Sequel.extension :symbol_as

def print_usage
  puts "USAGE: migrate_old_nailed_db <ABSOLUTE PATH TO OLD DB>"
  puts "Writes relevant data from an old nailed database in nailed_0.db"
  puts "Warning: This will write at ./db/nailed_0.db"
end


if ARGV.length != 1
  print_usage
  exit 1
end

path_old_db = ARGV[0]

if !File.file?(path_old_db)
  puts "ERROR: #{path_old_db} doesn't exit or is not a file"
  exit 2
end

begin
  DB_OLD = Sequel.connect("sqlite://#{path_old_db}")
  path_new_db = File.join(File.expand_path(File.dirname(__FILE__)),
                          "..", "nailed_0.db")
  DB_NEW = Sequel.connect("sqlite://#{path_new_db}")
rescue Exception => e
  puts "ERROR: Can't connect to database(s)"
  puts e
  exit 3
end

# create/migrate a nailed_0.db:
begin
  NailedDB.apply(DB_NEW, :up)
  puts "INFO: Created/Migrated nailed_0.db"
rescue Exception => e
  puts "ERROR: Can't migrate nailed_0.db"
  puts e
  exit 4
end


# bugreports and pullrequests don't need to be imported
# they should be fetched from bugzilla and github

# import bugtrends:
begin
  old_bugtrends = DB_OLD[:bugtrends].select(:time,
                                            :open,
                                            :fixed,
                                            :product_name).all
  old_bugtrends.each do |bugtrend|
    DB_NEW[:bugtrends].insert_conflict.insert(bugtrend)
  end
  puts "INFO: Imported bugtrends"
rescue Exception => e
  puts "ERROR: Can't import bugtrends"
  puts e
end


# import allbugtrends:
begin
  old_allbugtrends = DB_OLD[:allbug_trends].select(:time, :open).all
  old_allbugtrends.each do |allbugtrend|
    DB_NEW[:allbugtrends].insert_conflict.insert(allbugtrend)
  end
  puts "INFO: Imported allbugtrends"
rescue  Exception => e
  puts "ERROR: Can't import allbugtrends"
  puts e
end

# import l3trends:
begin
  old_l3trends = DB_OLD[:l3_trends].select(:time, :open).all
  old_l3trends.each do |l3trend|
    DB_NEW[:l3trends].insert_conflict.insert(l3trend)
  end
  puts "INFO: Imported l3trends"
rescue Exception => e
  puts "ERROR: Can't import l3trends"
  puts e
end

# import pulltrends, adjust column names:
begin
  old_pulltrends = DB_OLD[:pulltrends].
                     select(:time,
                            :open,
                            :closed,
                            :repository_rname.as(:rname),
                            :repository_organization_oname.as(:oname)).all
  old_pulltrends.each do |pulltrend|
    DB_NEW[:pulltrends].insert_conflict.insert(pulltrend)
  end
  puts "INFO: Imported pulltrends"
rescue Exception => e
  puts "ERROR: Can't import pulltrends"
  puts e
end

# import allpulltrends:
begin
  old_allpulltrends = DB_OLD[:allpull_trends].select(:time, :open, :closed).all
  old_allpulltrends.each do |allpulltrend|
    DB_NEW[:allpulltrends].insert_conflict.insert(allpulltrend)
  end
  puts "INFO: Imported allpulltrends"
rescue Exception => e
  puts "ERROR: Can't import allpulltrends"
  puts e
end

# Done:
puts "SUCCESS: Database imported"
