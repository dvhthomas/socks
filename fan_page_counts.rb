require 'rubygems'
require 'yaml'
require 'net/http'
require 'json'
require 'csv'

config = YAML.load_file('config/config.yml')['facebook']['sources']
sources = {}

config.each do |group|
	group[1].each do |source|
		sources[source[0]] = source[1]
	end
end

sources.sort

# download ids
CSV.open('./fan_counts.csv', 'wb') do |output|
	output << ["fb_id","name","fans"]
	sources.each do |key,value|
		json = Net::HTTP.get('graph.facebook.com', "/#{value}")
		result = JSON.parse(json)
		fan_count = result['fan_count'] 
		name = result['name'] 
		puts "#{name} has #{fan_count} fans"
		output << [value, "#{name}", fan_count]
	end
end
