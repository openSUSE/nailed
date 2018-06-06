Sequel.extension :migration, :core_extensions
# current default Nailed database schema:
class NailedDB < Sequel::Migration
  def up
    ## Bugzilla tables:
    create_table? :bugreports do
      integer :bug_id, primary_key: true
      text :summary
      string :status, null: false
      boolean :is_open, null: false
      string :product_name, null: false
      string :component
      string :severity
      string :priority
      string :whiteboard
      string :assigned_to
      DateTime :creation_time
      DateTime :last_change_time
      String :url
      text :requestee
    end

    # stores product specific trends:
    create_table? :bugtrends do
      DateTime :time, null: false
      Integer :open, null: false
      Integer :fixed, null: false
      string :product_name, null: false

      primary_key [:time, :product_name], name: :bugtrend_identifier
    end

    # stores trend of all products combined:
    create_table? :allbugtrends do
      DateTime :time, primary_key: true
      Integer :open

    end

    create_table? :l3trends do
      DateTime :time, primary_key: true
      Integer :open

    end

    ## Github tables:
    create_table? :pullrequests do
      Integer :pr_number, null: false
      String :title, null: false
      String :state, null: false
      String :url, null: false
      String :rname, null: false
      String :oname
      DateTime :created_at
      DateTime :updated_at
      DateTime :closed_at
      DateTime :merged_at

      primary_key [:rname, :pr_number], name: :pr_identifier
    end

    # stores trend of a specific repo:
    create_table? :pulltrends do
      DateTime :time
      Integer :open
      Integer :closed
      String :rname, null: false
      String :oname

      primary_key [:time, :rname], name: :pulltrend_identifier
    end

    # stores trend of all repos combined:
    create_table? :allpulltrends do
      DateTime :time, primary_key: true
      Integer :open
      Integer :closed
    end
  end

  def down
    self <<
      "DROP TABLE " /
      "bugreports, " /
      "bugtrends, " /
      "allbugtrends, " /
      "l3trends, " /
      "pullrequests, " /
      "pulltrends, " /
      "allpulltrends"
  end
end
