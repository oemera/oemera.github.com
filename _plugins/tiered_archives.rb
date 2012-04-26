# A quick and dirty plugin for Jekyll by Eli Naeher                                                                               
#                                                                                                                 
# This plugin creates a site.years template variable which allow you to group archive links by year and month.    
# The structure of site.years is:                                                                                 
# site.years = 2001=>[[post1, post2...], [...]], 2002=>[...]                                                
#                                                                                                                 
# Usage should look something like this:                                                                          
# {% for year in site.years %}                                                                                    
#   <h2>Year {{ year.first.first.date | date: "%Y" }}</h2>                                                        
#   {% for month in year %}                                                                                       
#     <h3>Month {{ month.first.date | date: "%B" }}</h3>                                                          
#     {% for post in month %}                                                                                     
#       <a href="{{ post.url">{{ post.title }}</a>                                                                
#     {% endfor %}                                                                                                
#   {% endfor %}                                                                                                  
# {% endfor %}                                                                                                    

class Jekyll::Site
  alias :site_payload_without_tiered_archives :site_payload
  
  def site_payload
    data = site_payload_without_tiered_archives
    data['site']['years'] = TieredArchives::find_years(self.posts.reverse)
    data['site']['months'] = TieredArchives::find_years(self.posts.reverse)
    data['site']['test'] = TieredArchives::find_last_five_months(self.posts.reverse)
    data
  end
end

module TieredArchives
  def self.find_years(posts)
    posts.group_by {|post| post.date.year}.values.map {|year| year.group_by {|post| post.date.month}.values};
  end
  def self.find_last_five_months(posts)
    years = self.find_years(posts)
    year = years[0] # => 2012
    
    count = 0
    arr = []
    years.each {|year|
      year.each {|month|
        if count < 5 
          arr.push(month)
          count += 1
        end
      }
    }
    arr
  end
end