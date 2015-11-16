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
      when "stderr", "STDERR", "", nil
        logfile = STDERR
      when "stdout", "STDOUT"
        logfile = STDOUT
      else
        require 'fileutils'
        logname = File.expand_path(logname, Dir.getwd) # expand relative to current dir
        logdir = File.dirname(logname)
        begin
          FileUtils.mkdir_p(logdir)
        rescue Exception => e
          STDERR.puts "Can't create log directory '#{logdir}': #{e}"
          exit 1
        end
      end
      if logfile.nil?
        begin
          logfile = File.new(logname, "a+")
        rescue Exception => e
          STDERR.puts "Log file creation '#{logname}' failed: #{e}"
          exit 1
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
