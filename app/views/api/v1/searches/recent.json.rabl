object nil

child search_result.results do
  attribute :id
  attribute :title, if: ->(o) { o.title.present? }
  attribute :description, if: ->(o) { o.description.present? }
  attribute :date_created, if:  ->(o) { o.date_created.present? }
  attribute :identifier, if: ->(o) { o.identifier.present? }
  attribute :collection_id, if: ->(o) { o.collection_id.present? }
  attribute :episode_title, if: ->(o) { o.episode_title.present? }
  attribute :series_title, if: ->(o) { o.series_title.present? }
  attribute :date_broadcast, if: ->(o) { o.date_broadcast.present? }
  attribute :tags, if: ->(o) { o.tags.present? }
  attribute :notes, if: ->(o) { o.notes.present? }
  attribute(:date_added, if: ->(o) { o.date_added.present? }) {|o| o.created_at }

  child :audio_files do
    attributes :url, :filename, :id
  end

  child(:entities, if: ->(o) { o.entities.present? }) do |e|
    extends 'api/v1/entities/entity'
  end

  node(:highlights, if: ->(o) { o.highlighted_audio_files.present? }) do |i|
    {audio_files: partial('api/v1/audio_files/audio_file', object: i.highlighted_audio_files) }
  end
end
