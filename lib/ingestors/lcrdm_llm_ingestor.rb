require 'open-uri'
require 'csv'
require 'nokogiri'

module Ingestors
  class LcrdmLlmIngestor < LlmIngestor
    def self.config
      {
        key: 'lcrdm_llm_event',
        title: 'LCRCDM LLM Events API',
        category: :events
      }
    end

    private

    def process_llm(_url)
      url = 'https://lcrdm.nl/evenementen/'
      event_page = Nokogiri::HTML5.parse(open_url(url.to_s, raise: true)).css('.archive__content > .column')
      event_page.each do |event_data|
        h2 = event_data.css('h2.post-item__title a')[0]
        new_url = h2.get_attribute('href').strip + '#llm'
        sleep(1) unless Rails.env.test? and File.exist?('test/vcr_cassettes/ingestors/lcrdm.yml')
        new_event_page = Nokogiri::HTML5.parse(open_url(new_url, raise: true)).css('main#main-content div.entry__inner')
        get_event_from_css(new_url, new_event_page)
      end
    end
  end
end
