require 'rubygems'
require 'rest_client'
require 'nokogiri'
require 'json'
require 'oauth2'
require 'uri'
require 'cgi'
require 'models/Profile'

module Facebook
	class InfoPane

		attr_accessor :stories, :user_name, :fql_feed, :fql_authors, :fql_user_targets, :fql_page_targets, :fql_photo

		@token = ''
		@user_id = ''

		def initialize(user, token)
			@stories = []
			@user_id = user['id']
			@user_name = user['first_name']
			@token = token
		end

		# Find the most recent best-of-the-best
		def find_popular
			results = call_fb
			doc = Nokogiri::XML(results)
			profiles = doc.css('profile')

			authors = {}
			(0..profiles.count-1).each do | i |
				author = Profile.new(profiles[i])
				authors[author.id] = author
			end

			posts = doc.css('stream_post')
			posts.each do | post |
				info_item = InfoStory.new(post)
				info_item.author = authors.fetch(info_item.posted_by_id)
				@stories.push(info_item)
			end

			photos = doc.css('fql_result fql_result_set photo')

			photos.each do |p|
				pid = p.css('pid').inner_text.to_i
				url = p.css('src_big').inner_text
				photo_story = @stories.select { |i| !i.attachment.nil?  and i.attachment.class == Facebook::AttachedPhoto and i.attachment.id == pid }
            photo_story.each {|p| p.attachment.big_url = url}
			end
		end

		def call_fb
			a_week_ago = (Time.now - 604800).to_i
			max_stories = 50
			#@fql_feed = "SELECT created_time, post_id, permalink, actor_id, target_id, message, comments.count, likes.count, likes.href, attachment FROM stream WHERE source_id in (SELECT target_id FROM connection WHERE (source_id='#{@user_id}' AND target_type='user')) and filter_key in (SELECT filter_key FROM stream_filter WHERE uid = #{@user_id} AND type = 'friendlist') AND is_hidden = 0 and created_time > #{a_week_ago} order by (likes.count+comments.count) DESC" # limit #{max_stories}"
			@fql_feed = "SELECT created_time, post_id, permalink, actor_id, target_id, message, comments.count, likes.count, likes.href, attachment FROM stream WHERE source_id in (SELECT target_id FROM connection WHERE (source_id='#{@user_id}' AND target_type='user')) order by (likes.count+comments.count) desc limit #{max_stories}"
			@fql_authors = 'SELECT id, name, url, pic_square FROM profile WHERE id IN (SELECT actor_id FROM #feed)'
			@fql_user_targets = 'SELECT id, url FROM profile WHERE id IN (SELECT target_id FROM #feed)'
			@fql_page_targets = 'SELECT page_id, page_url FROM page WHERE page_id IN (SELECT target_id FROM #feed)'
			@fql_photo = "SELECT pid, src_big from photo where pid in (SELECT attachment.media.photo FROM #feed WHERE attachment != '')"

			# make a hash to JSON-ify
			multi_query = {
				:feed => @fql_feed,
				:authors => @fql_authors,
				:user_targets => @fql_user_targets,
				:page_targets => @fql_page_targets,
				:big_photos => @fql_photo }

			# call Facebook
			url = 'https://api.facebook.com/method/fql.multiquery'
			results = RestClient.post url,
				:queries => multi_query.to_json,
				:access_token => @token,
				:format => 'xml'
                        File.open('./public/infopane.xml', 'w') {|f| f.write(results)}
			return results
		end
	end

	class InfoStory

		attr_accessor :message, :likes, :comments, :post_id, :posted_by_id, :created_on, :author, :attachment, :permalink, :type

		def initialize(news_item)
			@post_id = news_item.at_css('post_id').content
			@message = news_item.at_css('message').content unless news_item.at_css('message').nil?
			@permalink = news_item.at_css('permalink').content
			@created_on= Time.at(news_item.at_css('created_time').content.to_i) unless news_item.at_css('created_time').nil?
			@posted_by_id = news_item.at_css('actor_id').content.to_i unless news_item.at_css('actor_id').nil?
			@likes = news_item.at_css('likes count').content.to_i unless news_item.at_css('likes count').nil?
			@comments = news_item.at_css('comments count').content.to_i unless news_item.at_css('comments count').nil?

			description = news_item.at_css('attachment name').content unless news_item.at_css('attachment name').nil?
			attach = news_item.at_css('attachment media stream_media')

			@type = 'status'

			unless attach.nil?
				preview = attach.at_css('src').content unless attach.at_css('src').nil?
				target = news_item.at_css('attachment href').inner_text unless news_item.at_css('attachment href').nil?
				@type = attach.at_css('type').content

				if description.nil?
					description = attach.at_css('alt').content unless attach.at_css('alt').nil?
				end

				case @type
				when 'photo'
					pid = attach.at_css('photo pid').content.to_i
					owner_id = attach.at_css('photo owner').content.to_i
					album_index = attach.at_css('photo index').content.to_i unless attach.at_css('photo index').nil?
					width = attach.at_css('photo width').content.to_i
					height = attach.at_css('photo height').content.to_i
					@attachment = AttachedPhoto.new(preview, description, @type,target, pid, width, height)
			  	when 'video'
					#preview = CGI.parse(attach.at_css('src').inner_text)['url']
					unless attach.at_css('src').nil?
						preview = CGI.unescape(attach.at_css('src').inner_text)
						view_url = attach.at_css('video display_url').content
						description = news_item.at_css('attachment description').content unless news_item.at_css('attachment description').nil?
						link_title = news_item.at_css('name').content unless news_item.at_css('name').nil?
						@attachment = AttachedVideo.new(preview, description, @type, target, link_title, view_url)
					end
				when 'link'
				  preview = CGI.parse(attach.at_css('src').inner_text)['url']
							title = news_item.at_css('name').content unless news_item.at_css('name').nil?
							@attachment = AttachedLink.new(preview, description, @type,target,title)
				when 'swf'
					preview = attach.at_css('src').content
					album_index = attach.at_css('photo index').content.to_i unless attach.at_css('photo index').nil?
					@attachment = Attachment.new(preview, description, @type,target)
				else
					# don't do anything!
				end


			# Variety of possible messages to display. Pick the most general
				unless @attachment.nil?
					if @message == ''
					   @message = @attachment.description
					end
				end
			end
		end
	end

	class Attachment
		attr_accessor :preview, :description, :media_type, :target

		def initialize(preview_url, description, media_type,target)
			@preview = preview_url
			@description = description
			@media_type = media_type
			@target = target
		end
	end

	class AttachedPhoto < Attachment
		attr_accessor :id, :width, :height, :big_url

		def initialize(preview_url, description, media_type,target, photo_id, width, height)
			super(preview_url, description, media_type,target)
			@id = photo_id
                        @width = width
                        @height = height
		end
	end

	class AttachedLink < Attachment
		attr_accessor :link_title

		def initialize(preview_url, description, media_type, target, link_title)
			super(preview_url, description, media_type,target)
			@link_title = link_title
		end
	end

	class AttachedVideo < AttachedLink
		attr_accessor :view_url

		def initialize(preview_url, description, media_type, target, link_title, view_url)
			super(preview_url, description, media_type, target, link_title)
			@view_url = view_url
		end
	end
end
