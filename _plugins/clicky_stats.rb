require 'open-uri'
require 'pp'
require 'ostruct'
require 'yaml'
require 'jekyll'
require 'hpricot'
require 'nokogiri'
require 'digest/md5'

# From http://api.rubyonrails.org/classes/ActiveSupport/CoreExtensions/Hash/Keys.html
class Hash
  def stringify_keys!
    keys.each do |key|
      self[key.to_s] = delete(key)
    end
    self
  end
end

#
# Parses a clicky stats feed and returns items as an array.
#
class Clicky
  class << self
    def tag(site_id, site_key)
      popular_posts = []
      url = "http://api.getclicky.com/api/stats/4?site_id=#{site_id}&sitekey=#{site_key}&type=pages&date=last-30-days"
      doc = Nokogiri::XML(open(url))
      doc.xpath('//item').each do |i|
        url = i.xpath("url").first.content
        if /http:\/\/dailyoemer.com\/[0-9]{4}\/[0-9]{2}\/[0-9A-Za-z\-_\.]*.html/.match(url)
          item = OpenStruct.new

          title = i.xpath("title").first.content
          value = i.xpath("value").first.content.to_i rescue nil
          item.link = url
          item.title = title
          item.value = value

          popular_posts << item
        end
      end

      popular_posts.sort! {|a,b| b.value <=> a.value }
      popular_posts[0..4]
    end
  end
end

# 
# Cached version of the Clicky Jekyll tag.
#
class CachedClicky < Clicky
  DEFAULT_TTL = 600
  CACHE_DIR = '_clicky_cache'
  class << self
    def tag(site_id, site_key, ttl = DEFAULT_TTL)
      ttl = DEFAULT_TTL if ttl.nil?
      cache_key = "#{site_id}_#{site_key}"
      cache_file = File.join(CACHE_DIR, Digest::MD5.hexdigest(cache_key) + '.yml')

      FileUtils.mkdir_p(CACHE_DIR) if !File.directory?(CACHE_DIR)

      age_in_seconds = Time.now - File.stat(cache_file).mtime if File.exist?(cache_file)

      if age_in_seconds.nil? || age_in_seconds > ttl
#        p "old #{cache_file} #{age_in_seconds} < #{ttl}"
        result = super(site_id, site_key)
        File.open(cache_file, 'w') { |out| YAML.dump(result, out) }
      else
#        p "fresh"
        result = YAML::load_file(cache_file)
      end
      result
    end
  end
end

#
# Usage:
#   
#      <ul class="delicious-links">
#        {% delicious username:x tag:design count:15 ttl:3600 %}
#        <li><a href="{{ item.link }}" title="{{ item.description }}" rel="external">{{ item.title }}</a></li>
#        {% enddelicious %}
#      </ul>
#
# This will fetch the last 15 bookmarks tagged with 'design' from account 'x' and cache them for 3600 seconds.
# 
# Parameters:
#   site_id:  delicious username. For example, jebus.
#   site_key: delicious tag. For example, design. Separate multiple tags with a plus character. 
#             For example, business+tosite, will fetch boomarks tagged both business and tosite.
#   ttl:      The number of seconds to cache the feed. If not set, the feed will be fetched always.
#
module Jekyll
  class ClickyTag < Liquid::Block

    include Liquid::StandardFilters
    Syntax = /(#{Liquid::QuotedFragment}+)?/ 

    def initialize(tag_name, markup, tokens)
      @variable_name = 'item'
      @attributes = {}
      
      # Parse parameters
      if markup =~ Syntax
        markup.scan(Liquid::TagAttributes) do |key, value|
          #p key + ":" + value
          @attributes[key] = value
        end
      else
        raise SyntaxError.new("Syntax Error in 'clicky' - Valid syntax: clicky site_id:x site_key:x")
      end

      @ttl = @attributes.has_key?('ttl') ? @attributes['ttl'].to_i : nil
      @site_id = @attributes['site_id']
      @site_key = @attributes['site_key']
      @name = 'item'

      super
    end

    def render(context)
      context.registers[:delicious] ||= Hash.new(0)
    
      if @ttl
        collection = CachedClicky.tag(@site_id, @site_key, @ttl)
      else
        collection = Delicious.tag(@site_id, @site_key)
      end

      length = collection.length
      result = []
              
      # loop through found bookmarks and render results
      context.stack do
        collection.each_with_index do |item, index|
          attrs = item.send('table')
          context[@variable_name] = attrs.stringify_keys! if attrs.size > 0
          context['forloop'] = {
            'name' => @name,
            'length' => length,
            'index' => index + 1,
            'index0' => index,
            'rindex' => length - index,
            'rindex0' => length - index -1,
            'first' => (index == 0),
            'last' => (index == length - 1) }

          result << render_all(@nodelist, context)
        end
      end
      result
    end
  end
end

Liquid::Template.register_tag('clicky', Jekyll::ClickyTag)

if __FILE__ == $0
  require 'test/unit'

  class TC_MyTest < Test::Unit::TestCase
    def setup
      @result = Clicky::tag('37signals', 'svn')
    end

    def test_size
      assert_equal(@result.size, 5)
    end

    def test_bookmark
      bookmark = @result.first
      assert_equal(bookmark.title, 'Mike Rundle: "I now realize why larger weblogs are switching to WordPress...')
      assert_equal(bookmark.description, "...when a site posts a dozen or more entries per day for the past few years, rebuilding the individual entry archives takes a long time. A long, long time. &amp;lt;strong&amp;gt;About 32 minutes each rebuild.&amp;lt;/strong&amp;gt;&amp;quot;")
      assert_equal(bookmark.link, "http://businesslogs.com/business_logs/launch_a_socialites_life.php")
    end
  end
end
