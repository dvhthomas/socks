require 'rubygems'
require 'net/http'
require 'json'
require 'csv'
require 'rest_client'

data = CSV.read('./news_sources.csv')
data.shift

data.each do |row|
    id = row[1]
    puts id
    json = Net::HTTP.get('graph.facebook.com', "/#{id}")
    result = JSON.parse(json)
    photo = result['picture'] 
    data = RestClient.get(photo)
    name = result['name'] 
    puts "Downloading #{photo}..."
    File.open("./photos/#{name}_#{id}.jpg",'wb') {|f| f.write(data) }
end
