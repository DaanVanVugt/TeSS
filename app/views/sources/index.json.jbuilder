json.array!(@sources) do |source|
  json.extract! source, :content_provider, :created_at, :url,
                :method, :resource_type
  json.url source_url(source, format: :json)
end
