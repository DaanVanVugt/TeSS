require 'open-uri'
require 'csv'
require 'nokogiri'

module Ingestors
  class GptIngestor < Ingestor
    def self.config
      {
        key: 'gpt_event',
        title: 'GPT Events API',
        category: :events
      }
    end

    def read(url)
      begin
        process_gpt(url)
      rescue Exception => e
        @messages << "#{self.class.name} failed with: #{e.message}"
      end

      # finished
      nil
    end

    private

    def scrape_dans
      sleep(1) unless Rails.env.test? and File.exist?('test/vcr_cassettes/ingestors/gpt.yml')
      url = 'https://dans.knaw.nl/en/agenda/open-hour-ssh-live-qa-on-monday-2/'
      event_page = Nokogiri::HTML5.parse(open_url(url.to_s, raise: true)).css('body').css("div[id='nieuws_detail_row']")
      beep_func(url, event_page)
    end

    def scrape_nwo # rubocop:disable Metrics
      # sleep(1) unless Rails.env.test? and File.exist?('test/vcr_cassettes/ingestors/gpt.yml')
      # url = 'https://www.nwo.nl/en/meetings/dualis-event-in-utrecht'
      # event_page = Nokogiri::HTML5.parse(open_url(url, raise: true)).css('body').css('main')[0].css('article')
      # beep_func(url, event_page)
      url = 'https://www.nwo.nl/en/meetings'
      4.times.each do |i| # always check the first 4 pages, # of pages could be increased if needed
        sleep(1) unless Rails.env.test? and File.exist?('test/vcr_cassettes/ingestors/gpt.yml')
        event_page = Nokogiri::HTML5.parse(open_url("#{url}?page=#{i}", raise: true)).css('.overviewContent')[0].css('li.list-item').css('a')
        event_page.each do |event_data|
          new_url = "https://www.nwo.nl#{event_data['href']}"
          sleep(1) unless Rails.env.test? and File.exist?('test/vcr_cassettes/ingestors/gpt.yml')
          new_event_page = Nokogiri::HTML5.parse(open_url(new_url, raise: true)).css('body').css('main')[0].css('article')
          beep_func(new_url, new_event_page)
        end
      end
    end

    def scrape_rug # rubocop:disable Metrics
      # sleep(1) unless Rails.env.test? and File.exist?('test/vcr_cassettes/ingestors/gpt.yml')
      # url = 'https://www.rug.nl/about-ug/latest-news/events/calendar/2023/phallus-tentoonstelling'
      # event_page = Nokogiri::HTML5.parse(open_url(url.to_s, raise: true)).css('body').css("div[id='main']")[0].css("div[itemtype='https://schema.org/Event']")
      # beep_func(url, event_page)
      url = 'https://www.rug.nl/wubbo-ockels-school/calendar/2024/'
      # event_page = Nokogiri::HTML5.parse(open_url(url.to_s, raise: true)).css('body')[0].css("div[class='rug-mb']")[0].css("div[itemtype='https://schema.org/Event']")
      event_page = Nokogiri::HTML5.parse(open_url(url.to_s, raise: true)).css('body').css("div[id='main']")[0].css("div[itemtype='https://schema.org/Event']")
      event_page.each do |event_data|
        new_url = event_data.css("meta[itemprop='url']")[0].get_attribute('content')
        sleep(1) unless Rails.env.test? and File.exist?('test/vcr_cassettes/ingestors/gpt.yml')
        new_event_page = Nokogiri::HTML5.parse(open_url(new_url.to_s, raise: true)).css('body').css("div[id='main']")[0].css("div[itemtype='https://schema.org/Event']")
        beep_func(new_url, new_event_page)
      end
    end

    def scrape_tdcc
      sleep(1) unless Rails.env.test? and File.exist?('test/vcr_cassettes/ingestors/gpt.yml')
      url = 'https://tdcc.nl/evenementen/teaming-up-across-domains/'
      event_page = Nokogiri::HTML5.parse(open_url(url.to_s, raise: true)).css('body').css('article')[0]
      beep_func(url, event_page)
    end

    def process_gpt(_url)
      scrape_dans
      scrape_nwo
      scrape_rug
      scrape_tdcc
      # json not necessary (SURF, UvA)
      # XML not necessary (wur)
    end

    def unload_json(event, response)
      response_json = JSON.parse(response)
      response_json.each_key do |key|
        event[key] = response_json[key]
      end
      event
    end

    def scrape_func(event, event_page)
      response = ChatgptService.new.scrape(event_page).dig('choices', 0, 'message', 'content')
      puts response
      unload_json(event, response)
    end

    def post_process_func(event)
      response = ChatgptService.new.process(event).dig('choices', 0, 'message', 'content')
      puts response
      unload_json(event, response)
    end

    def beep_func(url, event_page) # rubocop:disable Metrics
      event_page.css('script, link').each { |node| node.remove }
      event_page = event_page.text.squeeze(" \n").squeeze("\n").squeeze("\t").squeeze(' ')
      begin
        event = OpenStruct.new
        event = scrape_func(event, event_page)
        event = post_process_func(event)
        event.url = url
        event.source = 'GPT'
        event.timezone = 'Amsterdam'
        add_event(event)
      rescue Exception => e
        puts e
        @messages << "Extract event fields failed with: #{e.message}"
      end
    end
  end
end
