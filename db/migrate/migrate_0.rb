require 'sequel'

#
# Migration from nailed_0.db to current db version
#
Sequel.extension :symbol_as

# connect to the db's
@old_db_path = Dir[File.join(File.dirname(__FILE__), "..", "nailed_0.db")].join

if !@old_db_path.empty?

  OLD_DB = Sequel.connect("sqlite://#{@old_db_path}")

  db_path = ENV["DATABASE_URL"]
  db_path ||= Dir[File.join(File.dirname(__FILE__), "..",
                            "nailed_#{Nailed::VERSION}.db")].join

  NEW_DB = Sequel.connect("sqlite://#{db_path}") unless db_path.empty?

else
  Nailed.logger.debug("No nailed_0.db detected")
end

# run db migration
def migrateDB

  if !@old_db_path.empty?

    Nailed.logger.info("Initializing db migration ...")

    # bugreports will be fetched from Bugzilla, no need to
    # migrate them.

    # import bugtrends:
    begin
      old_bugtrends = OLD_DB[:bugtrends].all
      old_bugtrends.each do |bugtrend|
        NEW_DB[:bugtrends].insert_conflict.insert(bugtrend)
      end
      Nailed.logger.info("Imported bugtrends")
    rescue Exception => e
      Nailed.logger.error("Cant't import bugtrends")
      Nailed.logger.error(e.message)
    end

    # import allbugtrends:
    begin
      old_allbugtrends = OLD_DB[:allbugtrends].all
      old_allbugtrends.each do |allbugtrend|
        NEW_DB[:allbugtrends].insert_conflict.insert(allbugtrend)
      end
      Nailed.logger.info("Imported allbugtrends")
    rescue Exception => e
      Nailed.logger.error("Cant't import allbugtrends")
      Nailed.logger.error(e.message)
    end

    # import l3trends:
    begin
      old_l3trends = OLD_DB[:l3trends].all
      old_l3trends.each do |l3trend|
        NEW_DB[:l3trends].insert_conflict.insert(l3trend)
      end
      Nailed.logger.info("Imported l3trends")
    rescue Exception => e
      Nailed.logger.error("Cant't import l3trends")
      Nailed.logger.error(e.message)
    end

    # import pullrequests:
    begin
      pullrequests = OLD_DB[:pullrequests].
        select(:pr_number.as(:change_number),
               :title,
               :state,
               :url,
               :rname,
               :oname,
               :created_at,
               :updated_at,
               :closed_at,
               :merged_at).all
      pullrequests.each do |pullrequest|
        NEW_DB[:changerequests].insert_conflict
          .insert(pullrequest.merge({origin: "github"}))
      end
      Nailed.logger.info("Imported pullrequests")
    rescue Exception => e
      Nailed.logger.error("Cant't import pullrequests")
      Nailed.logger.error(e.message)
    end

    # import pulltrends:
    begin
      pulltrends = OLD_DB[:pulltrends].all
      pulltrends.each do |pulltrend|
        NEW_DB[:changetrends].insert_conflict
          .insert(pulltrend.merge({origin: "github"}))
      end
      Nailed.logger.info("Imported pulltrends")
    rescue Exception => e
      Nailed.logger.error("Cant't import pulltrends")
      Nailed.logger.error(e.message)
    end

    # import allpulltrends:
    begin
      allpulltrends = OLD_DB[:allpulltrends].all
      allpulltrends.each do |allpulltrend|
        NEW_DB[:allchangetrends].insert_conflict
          .insert(allpulltrend.merge({origin: "github"}))
      end
      Nailed.logger.info("Imported allpulltrends")
    rescue Exception => e
      Nailed.logger.error("Cant't import allpulltrends")
      Nailed.logger.error(e.message)
    end

    # Done:
    if e.nil?
      Nailed.logger.info("SUCCESS: Database imported")
      File.rename("#{@old_db_path}", "#{@old_db_path}_migrated-#{Date.today.to_s}")
      Nailed.logger.info("Renamed old db file to:")
      Nailed.logger.info("nailed_0.db_migrated-#{Date.today.to_s}")
    end
  end
end
