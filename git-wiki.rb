#!/usr/bin/env ruby

%w(rubygems sinatra grit maruku rubypants haml).each do |a_gem| 
  begin
    require a_gem
  rescue LoadError => e
    puts "You need to 'sudo gem install #{a_gem}' before we can proceed"
  end
end

GIT_REPO = ENV['HOME'] + '/wiki'
GIT_DIR  = File.join(GIT_REPO, '.git')
HOMEPAGE = 'Home'

unless File.exists?(GIT_DIR) && File.directory?(GIT_DIR)
  FileUtils.mkdir_p(GIT_DIR)
  puts "Initializing repository in #{GIT_REPO}..."
  `git --git-dir #{GIT_DIR} init`
end

$repo = Grit::Repo.new(GIT_REPO)

class Page
  attr_reader :name

  def initialize(name)
    @name = name
    @filename = File.join(GIT_REPO, @name)
  end
  
  # The name with _'s replaced with spaces
  def title
    name.gsub(/_/, ' ')
  end

  # A derivation of body, which is actually displayed when showing a page.
  # It has stuff like [[links]] resolved as HTML links or placeholders if the
  # linked to page does not already exist
  def display_body
    pages = $repo.commits.first.tree.contents.map { |blob| Page.new(blob.name) }
    
    # mostly taken from JunebugWiki, regexps this beautiful should be shared
    raw_body.gsub(/\[\[([\w0-9A-Za-z -]+)[|]?([^\]]*)\]\]/) do
      page = title = $1.strip
      title = $2 unless $2.empty?
      page_url = page.gsub(/ /, '_')

      if pages.map(&:name).include?(page_url)
        %Q{<a href="/#{page_url}">#{title}</a>}
      else
        %Q{<span>#{title}<a href="/e/#{page_url}">?</a></span>}
      end
    end
    
  end

  def body
    @body ||= Maruku.new(RubyPants.new(raw_body).to_html).to_html
  end

  def raw_body
    @raw_body ||= File.exists?(@filename) ? File.read(@filename) : ''
  end

  def body=(content)
    File.open(@filename, 'w') { |f| f << content }
    message = tracked? ? "Edited #{@name}" : "Created #{@name}"
    `cd #{GIT_REPO} && git add #{@name} && git commit -m "#{message}"`
  end

  def tracked?
    return false if $repo.commits.empty?
    $repo.commits.first.tree.contents.map { |b| b.name }.include?(@name)    
  end

  def to_s
    "<li><strong><a href='/#{@name}'>#{@name}</a></strong> — <a href='/e/#{@name}'>edit</a></li>"
  end
end

get('/') { redirect '/' + HOMEPAGE }
get('/_stylesheet.css') { File.read('stylesheet.css') }

get '/_list' do
  if $repo.commits.empty?
    @pages = []
  else
    @pages = $repo.commits.first.tree.contents.map { |blob| Page.new(blob.name) }
  end
  
  haml(list)
end

get '/:page' do
  @page = Page.new(params[:page])
  @page.tracked? ? haml(show) : redirect('/e/' + @page.name)
end

get '/e/:page' do
  @page = Page.new(params[:page])
  haml(edit)
end

post '/e/:page' do
  @page = Page.new(params[:page])
  @page.body = params[:body]
  redirect '/' + @page.name
end

def layout(title, content)
  %Q(
%html
  %head
    %title #{title}
    %link{:rel => 'stylesheet', :href => '/_stylesheet.css', :type => 'text/css', :media => 'screen'}
    %meta{'http-equiv' => 'Content-Type', :content => 'text/html; charset=utf-8'}

  %body
    #navigation
      %a{:href => '/'} Home
      %a{:href => '/_list'} List
    #{content}
  )
end

def show
  layout(@page.title, %q(
      %a{:href => '/e/' + @page.name, :class => 'edit_link', :accesskey => 'e'} edit this page
    %h1{:class => 'page_title'}= @page.title
    #page_content= @page.display_body
  ))
end

def edit
  layout("Editing #{@page.title}", %q(
    %h1
      Editing
      = @page.title
      %a{:href => 'javascript:history.back()', :class => 'cancel'} Cancel
    %form{ :method => 'POST', :action => '/e/' + params[:page]}
      %p
        ~"<textarea name='body' rows='25' cols='130'>#{@page.raw_body}</textarea>"
      %p
        %input{:type => :submit, :value => 'Save as the newest version', :class => :submit}
  ))
end

def list
  layout('Listing pages', %q{
    %h1 All pages
    - if @pages.empty?
      %p No pages found.
    - else
      %ul= @pages.each(&:to_s)
  })
end

