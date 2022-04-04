module Utils
  def load_schema(part, version)
    path = "#{Dir.pwd}/spec/support/api/#{version}/api-schema.json"
    schema_stringified = File.read(path)
    JSON.parse(schema_stringified)[part]
  end

  def load_schema_get(part, version)
    load_schema(part, version)['get']
  end

  def load_schema_put(part, version)
    load_schema(part, version)['put']
  end

  def load_schema_patch(part, version)
    load_schema(part, version)['patch']
  end

  def load_schema_post(part, version)
    load_schema(part, version)['post']
  end

  def load_schema_delete(part, version)
    load_schema(part, version)['delete']
  end
end
