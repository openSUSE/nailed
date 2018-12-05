require 'sequel'
require_relative '../schema.rb'

# should be in nailed-class:
$CURRENT_DB_ID = Nailed::VERSION

db_path = File.join(File.expand_path(File.dirname(__FILE__)),
                      "..", "nailed_#{$CURRENT_DB_ID}.db")
DB = Sequel.connect("sqlite://#{db_path}")
def newDB
  NailedDB.apply(DB, :up)
end
