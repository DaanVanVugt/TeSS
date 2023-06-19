require 'test_helper'

class OscrIngestorTest < ActiveSupport::TestCase
  setup do
    @user = users(:regular_user)
    @content_provider = content_providers(:another_portal_provider)
    mock_ingestions
  end

  test 'can ingest events from oscr' do
    source = @content_provider.sources.build(
      url: 'https://www.openscience-rotterdam.com/tags/#workshops-list',
      method: 'oscr',
      enabled: true
    )

    ingestor = Ingestors::OscrIngestor.new

    # check event doesn't
    new_title = "A Tour around the Tidyverse World"
    new_url = 'https://www.openscience-rotterdam.com/2020/06/15/intro-tidyverse-june2020/'
    refute Event.where(title: new_title, url: new_url).any?

    # run task
    assert_difference 'Event.count', 7 do
      freeze_time(Time.new(2019)) do
        VCR.use_cassette("ingestors/oscr") do
          ingestor.read(source.url)
          ingestor.write(@user, @content_provider)
        end
      end
    end

    assert_equal 13, ingestor.events.count
    assert ingestor.materials.empty?
    assert_equal 13, ingestor.stats[:events][:added]
    assert_equal 0, ingestor.stats[:events][:updated]
    assert_equal 0, ingestor.stats[:events][:rejected]

    # check event does exist
    event = Event.where(title: new_title, url: new_url).first
    assert event
    assert_equal new_title, event.title
    assert_equal new_url, event.url

    # check other fields
    assert_equal 'OSCR', event.source
    assert_equal 'Amsterdam', event.timezone
    assert_equal 'Thu, 24 Jun 2020 14:00:00.000000000 UTC +00:00'.to_time, event.start
    assert_equal 'Thu, 24 Jun 2020 15:00:00.000000000 UTC +00:00'.to_time, event.end
    assert_equal 'Zoom', event.venue
    assert_equal true, event.online
  end
end
