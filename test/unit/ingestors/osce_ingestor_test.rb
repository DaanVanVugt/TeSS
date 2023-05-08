require 'test_helper'

class OsceIngestorTest < ActiveSupport::TestCase
  setup do
    @user = users(:regular_user)
    @content_provider = content_providers(:another_portal_provider)
    mock_ingestions
  end

  test 'can ingest events from osce' do
    source = @content_provider.sources.build(
      url: 'https://sites.google.com/view/osceindhoven/news-and-events',
      method: 'osce',
      enabled: true
    )

    ingestor = Ingestors::OsceIngestor.new

    # check event doesn't
    new_title = "4TU FAIR Data Day at TU/e"
    new_url = 'https://sites.google.com/view/osceindhoven/news-and-events/4TU-FAIR-Data-Day-at-TUe'
    refute Event.where(title: new_title, url: new_url).any?

    # run task
    assert_difference 'Event.count', 7 do
      freeze_time(Time.new(2019)) do
        VCR.use_cassette("ingestors/osce") do
          ingestor.read(source.url)
          ingestor.write(@user, @content_provider)
        end
      end
    end

    assert_equal 7, ingestor.events.count
    assert ingestor.materials.empty?
    assert_equal 7, ingestor.stats[:events][:added]
    assert_equal 0, ingestor.stats[:events][:updated]
    assert_equal 0, ingestor.stats[:events][:rejected]

    # check event does exist
    event = Event.where(title: new_title, url: new_url).first
    assert event
    assert_equal new_title, event.title
    assert_equal new_url, event.url

    # check other fields
    assert_equal 'OSCE', event.source
    assert_equal 'Amsterdam', event.timezone
    assert_equal 'Thu, 04 Apr 2019 12:45:00.000000000 UTC +00:00'.to_time, event.start
    assert_equal 'Thu, 04 Apr 2019 15:30:00.000000000 UTC +00:00'.to_time, event.end
    assert_equal 'TU/e campus, Luna 1.240', event.venue
  end
end
