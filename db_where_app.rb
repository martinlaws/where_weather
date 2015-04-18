require "sinatra"
require "json"
require "./models/stations.rb"
require "./models/observation.rb"
# require "./models/api_request.rb"
require "haversine"
require "byebug"
require "pg"
require "sequel"
require "logger"

DB = Sequel.connect('postgres://anncatton:@localhost:5432/mydb')
# DB.sql_log_level = :debug
DB.loggers << Logger.new($stdout)

get '/' do
	redirect to('/where_weather')
end

get '/where_weather' do

	stations_table = DB[:stations]
	observations_table = DB[:weather_data]
	
	def find_station(id, table)
		match = table.where(:station_id=>id.upcase).first
		match
	end
	
# not sure you need a valid check cuz the db search should ignore any records that are missing necessary values
# at some point you'll need to specify that temp, dewpoint and humidity are to be checked first, and then values like
# windspeed etc are more optional and can be checked on a second run
	# valid_stations = stations_to_compare.reject do |ea|
	# 	ea.not_valid?
	# end

	if params.empty? # this doesn't currently help when you load page without a query attached in the address bar. guess you'll have to
		# load it with an autoip query maybe? also _results_view has an if/else to handle matching_station being nil
		erb :index, :layout => :layout, :locals => { :matching_station => nil,
																								:locations_match => nil }
	else
		station_id = params[:id]
		station_to_match = find_station(station_id, observations_table) # station_to_match_data in api_request
		match_in_stations_table = stations_table.where(:id=>station_id.upcase).first
		station_to_match_data = Observation.from_table(station_to_match)

		station = Station.from_table(match_in_stations_table)

		all_matches = matches?(station_to_match_data, observations_table) # an array of hashes from observations table. not yet Observation instances
		all_matches_in_stations_table = all_matches.map do |ea| # all_matches_in_stations_table is data from stations
			stations_table.where(:id=>ea[:station_id].upcase).first
		end

		match_stations_data = all_matches_in_stations_table.map do |ea|
			Station.from_table(ea)
		end
		
		matches_not_too_close = match_stations_data.reject do |ea|
			too_close?(ea, station)
		end
	
		# matches = all_matches.map do |ea| # only if you need to display the weather conditions of the matches
		# 	Observation.from_table(ea)
		# end

		erb :index, :layout => :layout, :locals => {:station_to_match_data => station_to_match_data,
																								:station => station,
																								:matches_to_display => matches_not_too_close }
	end


end

# this populates the drop down with full location name using input from the user and matching with data from LOCATIONS
get '/location_search' do

  content_type :json
  query = params[:query]

  matches = stations.where(Sequel.ilike(:name, query+'%'))
  # matches = station_list.find_all do |ea|
  # 	next if ea[:name].nil? # do i need this anymore, now the database has a name for each location?
  # 	ea[:name].downcase.start_with?(query.downcase)
  # end

  content = if matches.empty?
  	erb :_no_result
	else
  	erb :_data_field, :layout => false, :locals => { :matches => matches }
	end

# what is this first_city section for?
	# first_city = if matches.empty?
	# 	erb :_no_result
	# else
	# 	erb :_display_span, :layout => false, :locals => {:first_match => matches.first }
	# end

 #  { :html => content, :first_match => first_city }.to_json

 { :html => content }.to_json

end