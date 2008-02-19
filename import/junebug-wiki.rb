#!/usr/bin/env ruby

#
# import/junebug-wiki.rb
# Import a JunebugWiki SQLite dump into a new or existing git-wiki repo

unless ARGV[0] && File.readable?(ARGV[0])
  puts "Usage: #{$0} path/to/junebug.db"
  exit 1
end