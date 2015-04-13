require "sinatra"
require "json"
require "./models/stations.rb"
require "./models/api_request.rb"
require "byebug"
require "pg"
require "sequel"
# require "time"
require "./models/stations_practice.rb"

DB = Sequel.connect('postgres://anncatton:@localhost:5432/mydb')

stations = DB[:stations]
observations = DB[:weather_data]

get '/' do
	redirect to('/where_weather')
end

get '/where_weather' do

	# hash of station hashes, main station keys (k) lowercase
	station_hash = parse_json_file("./weather_data/all_stations.json")

	# this matches a station id with a station id in the json conditions file. specific to all_stations
	def find_station(station_id)
		station_hash = parse_json_file("./weather_data/all_stations.json")
		station_hash[station_id.downcase]
	end

	# makes an array of Station instances
	stations_to_compare = station_hash.map do |k, v|
		Station.from_json(v)
	end

	valid_stations = stations_to_compare.reject do |ea|
		ea.not_valid?
	end


	if params.empty? # this doesn't currently help when you load page without a query attached in the address bar. guess you'll have to
		# load it with an autoip query maybe? also _results_view has an if/else to handle matching_station being nil
		erb :index, :layout => :layout, :locals => { :matching_station => nil,
																								:locations_match => nil }
	else
		station_id = params[:id]
		matching_station = find_station(station_id)
		locations_match = stations.where(:id=>station_id.upcase).first

		station = Station.from_json(matching_station)
		matches = valid_stations.find_all do |ea|
			ea != station && station.matches?(ea)
		end

		def find_pretty_match_station(station_to_match)
			stations = DB[:stations]
			match = stations.where(:id=>station_to_match.id.upcase).first
			# match = station_list.find do |ea|
			# 	match = ea[:id] == station_to_match.id
			# 	match
			# end

			match
		end

		erb :index, :layout => :layout, :locals => { :matching_station => matching_station,
																								:locations_match => locations_match,
																								:matches => matches }
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