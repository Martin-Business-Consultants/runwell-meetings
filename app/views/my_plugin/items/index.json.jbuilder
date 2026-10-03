json.summary "#{@items.size} pinned items"
json.items @items do |item|
  json.extract! item, :id, :body, :created_at
  json.client agent_ref(item.client)
  json.by item.user.display_name
end
