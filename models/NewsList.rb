require 'rubygems'
require 'rest_client'
require 'nokogiri'
require 'json'
require 'uri'
require 'cgi'
require 'models/Profile'

module Facebook

	class NewsList
		
		attr_accessor :stories, :author
		attr_accessor :fql_feed, :fql_comment, :fql_commenters, :fql_author
		attr_accessor :fql_story_photo, :results
		attr_accessor :all_comments

		def initialize
			@stories = []
		end

		def latest_updates(page_id)
			@results = call_fb(page_id)
			#return 'results'
			doc = Nokogiri::XML(results)
			profile = doc.css('profile')
			@author = Facebook::Profile.new(profile)
			comments = doc.css('comment')
			@all_comments = []
			comments.each do | c |
				comment = Comment.new(c)
				all_comments.push(comment)
			end

			items = doc.css('stream_post')
			items.each do | post |
				#news_item = NewsStory.new(post, @author.picture_url)
				news_item = NewsStory.new(post, @author.picture_url, all_comments)
			  @stories.push(news_item) unless news_item.headline.nil? 
			end
		end

		def call_fb(page_id)
			a_week_ago = (Time.now - 604800).to_i
			max_stories = 20
			@fql_feed = "SELECT created_time, updated_time, post_id, actor_id, target_id, message, permalink, comments.count, likes.count, likes.href, attachment, action_links FROM stream WHERE source_id =#{page_id} and actor_id=#{page_id} AND is_hidden = 0 and created_time > #{a_week_ago} AND comments.count > 0 order by comments.count DESC limit #{max_stories}"
			@fql_author = "select id, name, url, pic_square from profile where id = #{page_id}"
			@fql_story_photo = "select pid, src_big from photo where pid in (select attachment.media.photo from #feed where attachment !='')"
			@fql_comment = 'select post_id,time from comment where post_id in (select post_id from #feed) order by time desc'

			multi_query = {
				:feed => @fql_feed,
			    :author => @fql_author,
				:photo => @fql_story_photo,
				:comments => @fql_comment}
			url = 'https://api.facebook.com/method/fql.multiquery'
			results = RestClient.post url,
				:queries => multi_query.to_json,
				:format => 'xml'
			File.open('./public/news.xml', 'w') {|f| f.write(results)}
			return results
		end
	end

	class NewsStory

        attr_accessor :post_id, :comment_count, :like_count, :headline, :excerpt, :source_url, :thumbnail
		attr_accessor :created_time, :updated_time, :permalink

		def initialize(news_item, default_thumbnail, comments)
			@post_id = news_item.at_css('post_id').content
            c = Time.at(news_item.at_css('created_time').content.to_i)
      		@created_time = c.strftime("%I:%M%p, %b-%d-%Y")

			# get latest update time by finding the most recent comment
			# assumes that fql already sorted by time descending so just pick first
			time = comments.select{|c| c.post_id == @post_id}[0].time

			if time.nil?
				@updated_time = @created_time
			else
                @updated_time = time.strftime("%I:%M%p, %b-%d-%Y")
			end

			@headline = news_item.at_css('name').content unless news_item.at_css('name').nil?
			@excerpt = news_item.at_css('description').content unless news_item.at_css('description').nil?
			@source_url = news_item.at_css('href').content unless news_item.at_css('href').nil?
			@comment_count = news_item.at_css('comments count').content unless news_item.at_css('comments count').nil?
			@like_count = news_item.at_css('likes count').content.to_i unless news_item.at_css('likes count').nil?
			@permalink = news_item.at_css('permalink').content unless news_item.at_css('permalink').nil?
			picture = news_item.at_css('stream_media src')

			if(picture.nil?)
				@thumbnail = default_thumbnail
			else
				@thumbnail = CGI.parse(CGI.unescape(picture.content))['url']
			end
		end
	end

	class Comment
        attr_accessor :time, :post_id

		def initialize(comment)
			@time = Time.at(comment.at_css('time').content.to_i)
			@post_id = comment.at_css('post_id').content
		end
	end
end
