require 'nokogiri'

module Facebook
    class Profile
        attr_accessor :id, :profile_url, :name, :picture_url

        def initialize(info)
            @id = info.at_css('id').content.to_i
            @name = info.at_css('name').content unless info.at_css('name').nil?
            @profile_url = info.at_css('url').content unless info.at_css('url').nil?
            @picture_url = info.at_css('pic_square').content unless info.at_css('pic_square').nil?
        end
    end
end
