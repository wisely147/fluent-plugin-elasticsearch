module Fluent::ElasticsearchIndexTemplate

  def get_template(template_file)
    if !File.exists?(template_file)
      raise "If you specify a template_name you must specify a valid template file (checked '#{template_file}')!"
    end
    file_contents = IO.read(template_file).gsub(/\n/,'')
    JSON.parse(file_contents)
  end

  def template_exists?(name)
    client.indices.get_template(:name => name)
    return true
  rescue Elasticsearch::Transport::Transport::Errors::NotFound
    return false
  end

  def retry_install(max_retries)
    return unless block_given?
    retries = 0
    begin
      yield
    rescue Fluent::Plugin::ElasticsearchOutput::ConnectionFailure, Timeout::Error => e
      @_es = nil
      @_es_info = nil
      if retries < max_retries
        retries += 1
        sleep 2**retries
        log.warn "Could not push template(s) to Elasticsearch, resetting connection and trying again. #{e.message}"
        retry
      end
      raise Fluent::Plugin::ElasticsearchOutput::ConnectionFailure, "Could not push template(s) to Elasticsearch after #{retries} retries. #{e.message}"
    end
  end

  def template_put(name, template)
    client.indices.put_template(:name => name, :body => template)
  end

  def template_install(name, template_file, overwrite)
    if overwrite
      template_put(name, get_template(template_file))
      log.info("Template '#{name}' overwritten with #{template_file}.")
      return
    end
    if !template_exists?(name)
      template_put(name, get_template(template_file))
      log.info("Template configured, but no template installed. Installed '#{name}' from #{template_file}.")
    else
      log.info("Template configured and already installed.")
    end
  end

  def templates_hash_install(templates, overwrite)
    templates.each do |key, value|
      template_install(key, value, overwrite)
    end
  end

end
