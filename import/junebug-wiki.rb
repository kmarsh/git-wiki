#!/usr/bin/env ruby
require 'rubygems'
require 'sqlite3'
 
#
# import/junebug-wiki.rb
# Import a JunebugWiki SQLite dump into a new or existing git-wiki repo
# Warning: Will overwrite pages/files that already exist. Git diff to the rescue

GIT_REPO = ENV['HOME'] + '/wiki'

unless ARGV[0] && File.readable?(ARGV[0])
  puts "Usage: #{$0} path/to/junebug.db"
  exit 1
end

# TODO: Pull in historical pages, too, from junebug_page_versions. Will have to
# figure out how to 'backdate' commits, which must be possible because SVN import
# stuff does it. This will suffice for now.
db = SQLite3::Database.new(ARGV[0])
db.execute("SELECT title, body FROM junebug_pages") do |row|
  title, body = *row
  name = title.gsub(/ /, '_')
  
  # write to file
  filename = File.join(GIT_REPO, name)
  File.open(filename, 'w') { |f| f << body }
end

# Commit our changes to the repository
`cd #{GIT_REPO} && git add . && git commit -m "Import from junebug-wiki.rb"`