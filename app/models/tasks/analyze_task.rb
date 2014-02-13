require 'uri'

class Tasks::AnalyzeTask < Task

  after_commit :create_analyze_job, :on => :create

  def finish_task
    connection = Fog::Storage.new(storage.credentials)
    uri        = URI.parse(destination)

    analysis   = download_file(connection, uri)    
    process_analysis(analysis)
  end

  def process_analysis(analysis)
    item = owner.item
    return unless item

    existing_names = item.entities.collect{|e| e.name || ''}.sort.uniq
    analysis = JSON.parse(analysis) if analysis.is_a?(String)
    ["entities", "locations", "relations", "tags", "topics"].each do |category|
      analysis[category].each{|analysis_entity|
        name = analysis_entity.delete('name')
        if category == "topics"
          next if (name.blank? || existing_names.include?(name))
          create_entity(name, item, category, analysis_entity)
        elsif category == "tags"
          next if (name.blank? || existing_names.include?(name) || control_the_vocab(name.try(:singularize)))
          create_entity(name.try(:singularize), item, category, analysis_entity)
        else
          next if (name.blank? || existing_names.include?(name) || control_the_vocab(name))
          create_entity(name, item, category, analysis_entity)
        end
      }
    end
  end
  
  def control_the_vocab(term)
    #Check to see if term exists in DBPedia
    results=Dbpedia.search(term).collect(&:label).map(&:downcase)
    !results.include?(term.downcase)
  end
  
  def create_entity(name, item, category, analysis_entity)
    entity = item.entities.build

    entity.category     = category.try(:singularize)
    entity.entity_type  = analysis_entity.delete('type')
    entity.is_confirmed = false
    entity.name         = name
    entity.identifier   = analysis_entity.delete('guid')
    entity.score        = analysis_entity.delete('score')

    # anything left over, put it in the extra
    entity.extra        = analysis_entity
    entity.save
  end

  def create_analyze_job
    j = create_job do |job|
      job.job_type    = 'text'
      job.original    = original
      job.retry_delay = 3600 # 1 hour
      job.retry_max   = 24 # try for a whole day
      job.priority    = 3

      job.add_task({
        task_type: 'analyze',
        label:     self.id,
        result:    destination,
        call_back: call_back_url
      })
    end
  end

  def destination
    extras['destination'] || owner.try(:destination, {
      storage: storage,
      suffix:  '_analysis.json',
      options: { metadata: {'x-archive-meta-mediatype'=>'data' } }
    })
  end

end
