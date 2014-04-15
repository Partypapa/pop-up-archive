class FeedPopUp
  require 'uri'
  require 'pathname'
  # adding this for testing feed parsing in an easier way
  attr_accessor :dry_run

  def self.update_from_feed(feed_url, collection_id, dry_run=false)
    feed_pop_up = FeedPopUp.new(dry_run)
    feed_pop_up.parse(feed_url, collection_id)
  end

  def initialize(dry_run=false)
    self.dry_run = dry_run
  end

  def parse(feed_url, collection_id)
    puts "******************  IN PARSE FUNCTINO ********************"
    able_to_parse = true
    collection = Collection.find(collection_id) # this will throw an error if not present
    feed = Feedzirra::Feed.fetch_and_parse(feed_url, :on_failure => lambda {|url, response_code, header, body| able_to_parse = false if response_code == 200 })

    if able_to_parse && feed.entries && feed.entries.size > 0
      add_entries(feed.entries, collection)
    else
      logger.info "Error: Check feed url #{feed_url}"
    end
  end

  def add_entries(entries, collection)
    newItems = 0
    entries.each do |entry|
      unless Item.where(identifier: id(entry), collection_id: collection.id).exists?
        item = add_item_from_entry(entry, collection)
        newItems += 1
      end
    end
    logger.info "#{newItems} new items for collection: #{collection.id}"
  end

  def add_item_from_entry(entry, collection)
    item = Item.new

    item.collection       = collection
    item.description      = sanitize_text(entry.summary)
    item.title            = entry.title
    item.identifier       = id(entry)
    item.digital_location = entry.url
    item.date_broadcast   = entry.published
    item.date_created     = entry.published
    item.tags = entry.respond_to?(:categories) ? entry.categories : []
    
    author = author(entry)
    item.creators         = [author] if author
    # puts "*******************" + entry.inspect.to_s + "******************************"
    puts "******************* ABOUT TO ADD AUDIO FILES AND IMAGE FILES ********************************" 
    add_audio_files(item, entry, collection)
    add_image_files(item, entry, collection)
  
    item.save! unless dry_run
    item
  end

  def author(entry)
    n = entry.try(:author) ? entry.author.sanitize.squish : nil
    p = Person.for_name(n) if n
    p
  end

  def id(entry)
    entry.try(:enclosure_url) ||
    entry.try(:entry_id) ||
    entry.try(:guid) ||
    entry.try(:url) ||
    generate_id(entry)
  end

  def generate_id(entry)
    uniq = "#{entry.title.sanitize}|#{entry.published}"
    Digest::MD5.hexdigest(uniq)
  end

  def add_audio_files(item, entry, collection)
    if entry['enclosure_url']
      add_audio_file(item, entry.enclosure_url, collection)
    end
  end

  def add_audio_file(item, url, collection)
    puts "******************* in add_audio_file method****************************"
    url = CGI.unescapeHTML(url)
    return unless Utils.is_audio_file?(url)
    audio = AudioFile.new
    audio.user            = collection.creator
    audio.identifier      = url
    audio.remote_file_url = url
    item.audio_files << audio
    audio
  end
  
  def add_image_files(item, entry, collection)
    if entry['image'] 
      puts "LINE 101*****************" + entry.inspect.to_s + "**************************" + entry['image'].to_s
      add_image_file(item, entry.image, collection) 
      puts "********* in a add_image_files method***********************"
    else return
    end
  end

  def add_image_file(item, url, collection)
    # puts "****************" + item.inspect.to_s + "**************************" 
# uri = URI.parse(URI.encode(url.strip))  
    puts "*******************" + collection.inspect.to_s    
    url = CGI.unescapeHTML(url)
    uri = URI.parse(URI.encode(url.strip))     
    return unless Utils.is_image_file?(url)
    image_file = ImageFile.new
    file_name = Pathname.new(uri.path).basename.to_s
    image_file.file = file_name
    # puts "!!!!!!!!!!!!!!!!!!!!!!" + image_file.file.inspect.to_s + "!!!!!!!!!!!!!!!!!!!!!!!!!!" 
    puts "@@@@@@@@@@@@@@@@@@@@@" + uri.to_s + "@@@@@@@@@@@@@@@@@@@@@@@@@@@" + "111111111" + uri.path.to_s + "11111111" + file_name + "####################"
    image_file.original_file_url = url
    image_file.remote_file_url = url
    image_file.item_id = item.id
    image_file.storage_id = collection.default_storage_id
    # image_file.stoorage_id = collection.storage
    image_file.remote_file_url = url
    # image_file.file_uploaded(file_name)  
    # image_file.save!  
    # image_file.save_thumb_version(file_name.to_s)
    item.image_files << image_file
    puts "&&&&&&&&&&&&&&&&&&&&&&&&&&" + image_file.inspect.to_s + "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"
    image_file
  end

  def sanitize_text(text)
    transformer = lambda do |env|
      node      = env[:node]
      node_name = env[:node_name]

      # Don't continue if this node is already whitelisted or is not an element.
      return if env[:is_whitelisted] || !node.element?

      # Don't continue unless the node is an div.
      return unless node_name == 'div'

      # We're now certain that this is a div in the summary,
      Sanitize.clean_node!(node)

      # Now that we're sure that this is a valid YouTube embed and that there are
      # no unwanted elements or attributes hidden inside it, we can tell Sanitize
      # to whitelist the current node.
      {:node_whitelist => [node]}
    end

    Sanitize.clean(text,
      :transformers => transformer,
      :elements     => ['a', 'span'],
      :attributes   => {'a' => ['href', 'title'], 'span' => ['class']},
      :protocols    => {'a' => {'href' => ['http', 'https', 'mailto']}}
    )
  end

  def logger
    Rails.logger
  end

end

# class FeedPopUp

#   # adding this for testing feed parsing in an easier way
#   attr_accessor :dry_run

#   def self.update_from_feed(feed_url, collection_id, dry_run=false)
#     feed_pop_up = FeedPopUp.new(dry_run)
#     feed_pop_up.parse(feed_url, collection_id)
#   end

#   def initialize(dry_run=false)
#     self.dry_run = dry_run
#   end

#   def parse(feed_url, collection_id)
#     able_to_parse = true
#     collection = Collection.find(collection_id) # this will throw an error if not present
#     feed = Feedzirra::Feed.fetch_and_parse(feed_url, :on_failure => lambda {|url, response_code, header, body| able_to_parse = false if response_code == 200 })

#     if able_to_parse && feed.entries && feed.entries.size > 0
#       add_entries(feed.entries, collection)
#     else
#       logger.info "Error: Check feed url #{feed_url}"
#     end
#   end

#   def add_entries(entries, collection)
#     newItems = 0
#     entries.each do |entry|
#       unless Item.where(identifier: id(entry), collection_id: collection.id).exists?
#         item = add_item_from_entry(entry, collection)
#         newItems += 1
#       end
#     end
#     logger.info "#{newItems} new items for collection: #{collection.id}"
#   end

#   def add_item_from_entry(entry, collection)
#     item = Item.new

#     item.collection       = collection
#     item.description      = sanitize_text(entry.summary)
#     item.title            = entry.title
#     item.identifier       = id(entry)
#     item.digital_location = entry.url
#     item.date_broadcast   = entry.published
#     item.date_created     = entry.published
#     item.tags = entry.respond_to?(:categories) ? entry.categories : []
    
#     author = author(entry)
#     item.creators         = [author] if author

#     add_audio_files(item, entry, collection)
  
#     item.save! unless dry_run
#     item
#   end

#   def author(entry)
#     n = entry.try(:author) ? entry.author.sanitize.squish : nil
#     p = Person.for_name(n) if n
#     p
#   end

#   def id(entry)
#     entry.try(:enclosure_url) ||
#     entry.try(:entry_id) ||
#     entry.try(:guid) ||
#     entry.try(:url) ||
#     generate_id(entry)
#   end

#   def generate_id(entry)
#     uniq = "#{entry.title.sanitize}|#{entry.published}"
#     Digest::MD5.hexdigest(uniq)
#   end

#   def add_audio_files(item, entry, collection)
#     if entry['media_contents'] && entry.media_contents.size > 0
#       entry.media_contents.each{ |mc| add_audio_file(item, mc.url, collection) }
#     elsif entry['enclosure_url']
#       add_audio_file(item, entry.enclosure_url, collection)
#     end
#   end

#   def add_audio_file(item, url, collection)
#     url = CGI.unescapeHTML(url)
#     return unless Utils.is_audio_file?(url)
#     audio = AudioFile.new
#     audio.user            = collection.creator
#     audio.identifier      = url
#     audio.remote_file_url = url
#     item.audio_files << audio
#     audio
#   end

#   def sanitize_text(text)
#     transformer = lambda do |env|
#       node      = env[:node]
#       node_name = env[:node_name]

#       # Don't continue if this node is already whitelisted or is not an element.
#       return if env[:is_whitelisted] || !node.element?

#       # Don't continue unless the node is an div.
#       return unless node_name == 'div'

#       # We're now certain that this is a div in the summary,
#       Sanitize.clean_node!(node)

#       # Now that we're sure that this is a valid YouTube embed and that there are
#       # no unwanted elements or attributes hidden inside it, we can tell Sanitize
#       # to whitelist the current node.
#       {:node_whitelist => [node]}
#     end

#     Sanitize.clean(text,
#       :transformers => transformer,
#       :elements     => ['a', 'span'],
#       :attributes   => {'a' => ['href', 'title'], 'span' => ['class']},
#       :protocols    => {'a' => {'href' => ['http', 'https', 'mailto']}}
#     )
#   end

#   def logger
#     Rails.logger
#   end

# end
