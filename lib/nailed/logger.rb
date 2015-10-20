#
# Nailed::Logger
#
require 'logger'

module Nailed

  #
  # Logger
  #

  logfile = File.join(TOPLEVEL,"log")
  Dir.mkdir(logfile) rescue nil
  logfile = File.join(logfile, "nailed.log")
  File.new(logfile, "a+") unless File.exists?(logfile)
  LOGGER = Logger.new(logfile)

end