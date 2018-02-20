require 'sinatra'
require 'sequel'
require 'json'
Sequel.extension :core_extensions

DB_NAME = "links.db"

DB = Sequel.connect("sqlite://#{DB_NAME}")

class Link < Sequel::Model
  def hit!
    self.hits += 1
    self.save(:validate => false)
  end

  def validate
    super
    errors.add(:name, 'cannot be empty') if !name || name.empty?
    errors.add(:url, 'cannot be empty') if !url || url.empty?
  end
end


configure do
  set :erb, :escape_html => true
  set :server, :puma
  set :port, 80
end

# Actions

get '/' do
  @links = Link.order(:hits.desc).all
  erb :index
end

get '/links' do
  redirect '/'
end

post '/links' do
  begin
    Link.create(
      :name => params[:name],
      :url  => params[:url]
    )
    redirect '/'
  rescue Sequel::ValidationFailed,
         Sequel::DatabaseError => e
    halt "Error: #{e.message}"
  end
end

get '/links/suggest' do
  query = params[:q]

  results = Link.filter(:name.like("#{query}%")).or(:url.like("%#{query}%"))
  results = results.all.map {|r| r.name }

  content_type :json
  [query, results].to_json
end

get '/links/search' do
  query = params[:q]
  link  = Link[:name => query]

  if link
    redirect "/#{link.name}"
  else
    @links = Link.filter(:name.like("#{query}%"))
    erb :index
  end
end

get '/links/opensearch.xml' do
  content_type :xml
  erb :opensearch, :layout => false
end

get '/links/:id/remove' do
  link = Link.find(:id => params[:id])
  halt 404 unless link
  link.destroy
  redirect '/'
end

get '/:name/?*?' do
  link = Link[:name => params[:name]]
  halt 404 unless link
  link.hit!

  parts = (params[:splat].first || '').split('/')

  url = link.url
  url %= parts if parts.any?

  redirect url
end

