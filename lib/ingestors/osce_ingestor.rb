require 'open-uri'
require 'csv'
require 'nokogiri'

module Ingestors
  class OsceIngestor < Ingestor
    def self.config
      {
        key: 'osce_event',
        title: 'OSCE Events API',
        category: :events
      }
    end

    def read(url)
      begin
        process_osce(url)
      rescue Exception => e
        @messages << "#{self.class.name} failed with: #{e.message}"
      end

      # finished
      nil
    end

    private

    def process_osce(url)
      unless Rails.env.test? and File.exist?('test/vcr_cassettes/ingestors/osce.yml')
        sleep(1)
      end

      title_class = "hJDwNd-AhqUyc-uQSCkd Ft7HRd-AhqUyc-uQSCkd purZT-AhqUyc-II5mzb ZcASvf-AhqUyc-II5mzb pSzOP-AhqUyc-qWD73c Ktthjf-AhqUyc-qWD73c JNdkSc SQVYQc"
      event_class = "hJDwNd-AhqUyc-wNfPc Ft7HRd-AhqUyc-wNfPc purZT-AhqUyc-II5mzb ZcASvf-AhqUyc-II5mzb pSzOP-AhqUyc-wNfPc Ktthjf-AhqUyc-wNfPc JNdkSc SQVYQc yYI8W HQwdzb"
      
      ctr = 0
      event_page = Nokogiri::HTML5.parse(open_url(url.to_s, raise: true)).css("div[class='UtePc RCETm yxgWrb']")[0].css("section[class='yaqOZd']")
      event_page.each do |event_section|
        if event_section.css("div[class='#{title_class}']").length > 0
          ctr += 1
          if ctr == 2
            break
          end
        else
          event_section.css("div[class='#{event_class}']").each do |event_data|
            event = OpenStruct.new

            event.url = event_data.css("div[class='oKdM2c ZZyype']").first.css("span[class='C9DxTc aw5Odc ']")[0].parent.get_attribute('href')
            event.title = event_data.css("div[class='oKdM2c ZZyype']").first.css("span[class='C9DxTc aw5Odc ']")[0].text
            event.description = recursive_description_func(event_data.css("div[class='oKdM2c ZZyype']").last.css("p[class='zfr3Q CDt4Ke ']").first.parent)

            # event_page2 = Nokogiri::HTML5.parse(open_url(event.url.to_s, raise: true)).css("div[role='main']").first
            event_page1 = Nokogiri::HTML5.parse(open_url(event.url.to_s, raise: true))
            event_page2 = event_page1.css("div[role='main']").first

            event_page2&.css("section")&.each do |section|
              section&.css("p")&.each do |beep|
                boop = beep&.css("span")&.first
                case boop&.text&.strip
                when 'Where:', 'Place:'
                  event.venue = recursive_last_child_text(boop.parent)
                when 'When:'
                  time_str_split = recursive_last_child_text(boop.parent).split('-')
                  if time_str_split.length == 1
                    time_str_split = recursive_last_child_text(boop.parent).split('–')
                  end
                  event.start = time_str_split[0].to_time
                  end_time_split = time_str_split[1].split(' ')[0].split(':')
                  event.end = time_str_split[0].to_time.change(hour: end_time_split[0], min: end_time_split[1])
                end
              end
            end
            event.venue ||= 'Online'

            event.source = 'OSCE'
            event.timezone = 'Amsterdam'
            # event.set_default_times
            add_event(event)
          end
        end
      rescue Exception => e
        @messages << "Extract event fields failed with: #{e.message}"
      end
    end
  end
end

def recursive_description_func(css, res='')
  if css.children.length == 0
    # res += css&.text&.strip
    res += css&.text
  else
    css.children.each do |css2|
      res = recursive_description_func(css2, res)
    end
  end
  res
end

def recursive_last_child_text(css)
  if css.children.length == 0
    css.text
  else
    recursive_last_child_text(css.children.last)
  end
end