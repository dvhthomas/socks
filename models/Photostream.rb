require 'rubygems'
require 'rest_client'
require 'nokogiri'
require 'json'

module Facebook
	class Photostream
		attr_accessor :user, :fql_photo, :photos

		def initialize(token)
			rg = RestGraph.new(:access_token => token)
			@user = rg.get('me')
			id = @user['id']
			@fql_photo = "SELECT src_big, src_big_height, src_big_width FROM photo WHERE pid IN (SELECT cover_pid FROM album WHERE owner in (SELECT target_id FROM connection WHERE (source_id='#{id}' AND target_type='user'))  AND name = 'Profile Pictures')"

			multi_query = {:photos => @fql_photo}
			url = 'https://api.facebook.com/method/fql.multiquery'
			results = RestClient.post url,
					:queries => multi_query.to_json,
					:access_token => token,
					:format => 'xml'
			File.open('./public/photos.xml', 'w') {|f| f.write(results)}
			doc = Nokogiri::XML(results)
			@photos = doc.css('fql_result fql_result_set photo')
		end
	end
end
