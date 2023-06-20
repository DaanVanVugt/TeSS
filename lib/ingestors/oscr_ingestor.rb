require 'open-uri'
require 'csv'
require 'nokogiri'

module Ingestors
  class OscrIngestor < Ingestor
    def self.config
      {
        key: 'oscr_event',
        title: 'OSCR Events API',
        category: :events
      }
    end

    def read(url)
      begin
        process_oscr(url)
      rescue Exception => e
        @messages << "#{self.class.name} failed with: #{e.message}"
      end

      # finished
      nil
    end

    private

    def process_oscr(url)
      oscr_url = 'https://www.openscience-rotterdam.com/tags/#workshops-list'
      github_url = 'https://github.com/osc-rotterdam/osc-rotterdam.github.io/tree/development/content/post'

      workshop_title_list = []
      workshop_url_list = []
      event_page = Nokogiri::HTML5.parse(open_url(oscr_url.to_s, raise: true)).css("div[id='workshops-list']").first.css("li[class='archive-post']")
      event_page.each do |event_section|
        el = event_section.css("a[class='archive-post-title']").first
        workshop_title_list.append(el.text)
        workshop_title_list.append(el.get_attribute('href'))
      end

      puts 0
      byebug
      event_page = Nokogiri::HTML5.parse(open_url(github_url.to_s, raise: true)).css("tbody").first.css("tr[class='react-directory-row']")
      event_page.each do |event_section|
        puts 1
        new_url = event_section.css("a[class='Link--primary']").first.get_attribute('href') + '/index.Rmd'
        puts 2
        unless Rails.env.test? and File.exist?('test/vcr_cassettes/ingestors/oscr.yml')
          sleep(0.5)
        end
        github_text = Nokogiri::HTML5.parse(open_url(new_url.to_s, raise: true)).css("textarea[id='read-only-cursor-text-area]").first.text
        puts 3
        _, vars_text , description = github_text.split('---\n')
        puts 4
        dict = {}
        vars_text.split('\n').each do |txt|
          a, b = txt.split(':')
          dict[a.strip] = b.strip
        end
        puts 5
        if dict['title'] in workshop_title_list
          event = OpenStruct.new
          event.title = dict['title']
          event.url = workshop_url_list[workshop_title_list.index(dict['title'])]
          event.description = description
          date, time, venue = dict['summary'].split(',')
          event.start = (date + time.sub('h.','')).to_time
          event.venue = venue.strip
          event.keywords = []
          dict['tags'].sub('[','').sub(']','').split(',').each do |keyword|
            event.keywords << keyword.strip
          end
          event.source = 'OSCR'
          event.timezone = 'Amsterdam'
          event.set_default_times
          add_event(event)
        end
      rescue Exception => e
        @messages << "Extract event fields failed with: #{e.message}"
      end
    end
  end
end
