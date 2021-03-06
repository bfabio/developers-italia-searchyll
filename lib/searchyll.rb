require "searchyll/version"
require "jekyll/hooks"
require "jekyll/plugin"
require "jekyll/generator"
require "searchyll/configuration"
require "searchyll/indexer"
require "nokogiri"

begin
  indexers = {}

  Jekyll::Hooks.register(:site, :pre_render) do |site|
    config = Searchyll::Configuration.new(site)
    if config.valid?
      puts "setting up indexer hook"
      indexers[site] = Searchyll::Indexer.new(config)
      indexers[site].start
    else
      puts 'Invalid Elasticsearch configuration provided, skipping indexing...'
      config.reasons.each do |r|
        puts "  #{r}"
      end
    end
  end

  Jekyll::Hooks.register :site, :post_render do |site|
    if (indexer = indexers[site])
      indexer.finish
    end
  end

  # gets random pages like your home page
  Jekyll::Hooks.register :pages, :post_render do |page|
    # strip html
    nokogiri_doc = Nokogiri::HTML(page.output)

    # puts %(        indexing page #{page.url})

    if (indexer = indexers[page.site])
      indexer << ({
        "id"   => page.url,
        "url"  => page.url,
        "text" => nokogiri_doc.xpath("//article//text()").to_s.gsub(/\s+/, " ")
      }).merge(page.data)
    end
  end

  # gets both posts and collections
  Jekyll::Hooks.register :documents, :post_render do |document|
    # strip html
    nokogiri_doc = Nokogiri::HTML(document.output)

    # puts %(        indexing document #{document.url})

    if (indexer = indexers[document.site])
      indexer << ({
        "id"   =>  document.id,
        "url"  =>  document.url,
        "text" =>  nokogiri_doc.xpath("//article//text()").to_s.gsub(/\s+/, " ")
      }).merge(document.data)
    end
  end

rescue => e
  puts e.message
end
