#
# Nailed::Logger
#
require 'logger'

module Nailed

  class Logger < ::Logger
    def initialize
      logname = Config["logfile"]
      logfile = nil
      case logname
      when "stderr"
        logfile = STDERR
      when "stdout"
        logfile = STDOUT
      when "", nil
        logdir = File.join(TOPLEVEL,"log")
        Dir.mkdir(logdir) rescue nil
        logname = File.join(logdir, "nailed.log")
      else
        # assume valid file path
      end
      if logfile.nil?
        begin
          logfile = File.new(logname, "a+")
        rescue Exception => e
          STDERR.puts "Log file creation '#{logname}' failed: #{e}"
        end
      end
      super logfile
      self.level = case Config["debug"]
        when "debug" then Logger::DEBUG
        when "info" then Logger::INFO
        when "warn" then Logger::WARN
        when "error" then Logger::ERROR
        else
          Logger::FATAL
        end
    end
  end

end
