get "/account/:id.:format" do
  feed_only 

  unless user = User.find(params[:id])
    halt 404 and return
  end

  items = SeenItem.where(:user_id => user.id).desc(:date)

  if params[:format] == 'rss'
    rss_for items, params
  else
    json_for items, params
  end
end

get "/interest/:interest_id.:format" do
  feed_only

  unless interest = Interest.find(params[:interest_id])
    halt 404 and return
  end

  items = SeenItem.where(:interest_id => interest.id).desc :date

  if params[:format] == 'rss'
    rss_for items, params
  else
    json_for items, params
  end
end

get "/account/:id/tags/:tag.:format" do
  feed_only

  unless (user = User.find(params[:id])) and user.public_tags.include?(params[:tag])
    halt 404 and return
  end

  interest_ids = user.interests.where(:tags => params[:tag]).only(:_id).map &:_id
  items = SeenItem.where(:interest_id => {"$in" => interest_ids}).desc :date

  if params[:format] == 'rss'
    rss_for items, params
  else
    json_for items, params
  end
end

helpers do

  def feed_only
    halt 404 unless ['rss', 'json'].include?(params[:format])
  end

  def rss_for(items, params)
    page = (params[:page] || 1).to_i
    page = 1 if page <= 0 or page > 200000000
    per_page = 100

    items = items.skip(per_page * (page - 1)).limit(per_page)

    headers["Content-Type"] = "application/rss+xml"
    erb :"rss/user", :layout => false, :locals => {
      :items => items,
      :url => request.url
    }
  end
  
  def jsonp(results, params)
    response['Content-Type'] = 'application/json'
    json = results.to_json
    params[:callback].present? ? "#{params[:callback]}(#{json});" : json
  end


  def json_for(items, params)
    count = items.count
    
    pagination = pagination_for params
    skip = pagination[:per_page] * (pagination[:page]-1)
    limit = pagination[:per_page]
    items = items.skip(skip).limit(limit)

    results = {
      :results => items.map {|item| item.json_view},
      :count => count,
      :page => {
        :count => items.size,
        :per_page => pagination[:per_page],
        :page => pagination[:page]
      }
    }

    jsonp results, params
  end


  def pagination_for(params)
    default_per_page = 50
    max_per_page = 50
    max_page = 200000000 # let's keep it realistic
    
    # rein in per_page to somewhere between 1 and the max
    per_page = (params[:per_page] || default_per_page).to_i
    per_page = default_per_page if per_page <= 0
    per_page = max_per_page if per_page > max_per_page
    
    # valid page number, please
    page = (params[:page] || 1).to_i
    page = 1 if page <= 0 or page > max_page
    
    {:per_page => per_page, :page => page}
  end

end