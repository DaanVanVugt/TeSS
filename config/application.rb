require_relative 'boot'

require 'rails/all'

require_relative '../lib/i18n'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TeSS
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    config.eager_load_paths << Rails.root.join('lib')

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '*', headers: :any, methods: %i[get post options]
      end
    end

    config.tess = config_for(Rails.env.test? ? Pathname.new(Rails.root).join('test', 'config', 'test_tess.yml') : 'tess')
    config.tess_defaults = config_for('tess.example')

    # locales
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', 'overrides', '**', '*.{rb,yml}')] unless Rails.env.test?
    i18n_config = (config.tess_defaults.i18n || {}).deep_merge(config.tess.i18n || {})
    config.i18n.available_locales = i18n_config[:available_locales]&.map(&:to_sym)
    config.i18n.default_locale = i18n_config[:default_locale]&.to_sym
    case i18n_config[:fallback_strategy]
    when 'manual'
      config.i18n.fallbacks = i18n_config[:fallbacks] if i18n_config[:fallbacks].present?
    when 'simple',  'rfc4646'
      I18n.backend.class.include(I18n::Backend::Fallbacks)
      # Detect if any locale specifies any detail beyond primary
      # language subtag (e.g.: en-CA).
      any_has_subtags = i18n_config[:available_locales]&.any?(&I18n::Locale::Tag.method(:has_subtags?))
      if any_has_subtags
        # This is necessary for RFC4646-based fallbacks to work, as
        # I18n won't use resolve l10n keys from fallback locales that
        # are not in the `available_locales`.
        config.i18n.available_locales += i18n_config[:available_locales]
                                           &.map {|locale| I18n.fallbacks[locale] - [locale.to_sym] }
                                           &.flatten
      end
      if i18n_config[:fallback_strategy] == 'rfc4646'
        I18n::Locale::Tag.implementation = I18n::Locale::Tag::Rfc4646
      end
    else
      raise "Bad fallback strategy: #{i18n_config[:fallback_strategy]}"
    end

    config.active_record.yaml_column_permitted_classes = [
      Symbol, Date, Time, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone,
      ActiveSupport::HashWithIndifferentAccess, BigDecimal
    ]

    config.exceptions_app = routes
  end

  tess_config = Rails.configuration.tess.with_indifferent_access

  if tess_config['feature']&.key?('providers') && !tess_config['feature']&.key?('content_providers')
    warn "DEPRECATION WARNING: 'providers' should now be 'content_providers' under 'features' in: config/tess.yml"
    tess_config['feature']['content_providers'] = tess_config['feature']['providers']
  end

  if tess_config['feature']&.key?('e-learnings') && !tess_config['feature']&.key?('elearning_materials')
    warn "DEPRECATION WARNING: 'e-learnings' should now be 'elearning_materials' under 'features' in: config/tess.yml"
    tess_config['feature']['elearning_materials'] = tess_config['feature']['e-learnings']
  end

  if tess_config['placeholder']&.key?('provider') && !tess_config['placeholder']&.key?('content_provider')
    warn "DEPRECATION WARNING: 'provider' should now be 'content_provider' under 'placeholders' in: config/tess.yml"
    tess_config['placeholder']['content_provider'] = tess_config['placeholder']['provider']
  end

  def self.merge_config(default_config, config, current_path = '')
    default_config.each do |key, value|
      unless config.key?(key)
        puts "Setting '#{current_path}#{key}' not configured, using defaults" if Rails.env.development?
        config[key] = value
      end
      merge_config(value, config[key], current_path + "#{key}: ") if value.is_a?(Hash) && config[key].is_a?(Hash)
    end
  end

  merge_config(Rails.configuration.tess_defaults.with_indifferent_access, tess_config)

  class TessConfig < OpenStruct
    def redis_url
      if Rails.env.test?
        ENV.fetch('REDIS_TEST_URL') { 'redis://localhost:6379/0' }
      else
        ENV.fetch('REDIS_URL') { 'redis://localhost:6379/1' }
      end
    end

    def ingestion
      return @ingestion if @ingestion

      config_file = File.join(Rails.root, 'config', 'ingestion.yml')
      @ingestion = File.exist?(config_file) ? YAML.safe_load(File.read(config_file)).deep_symbolize_keys! : {}
    end

    def analytics_enabled
      force_analytics_enabled || (Rails.application.secrets.google_analytics_code.present? && Rails.env.production?)
    end

    def map_enabled
      !feature['disabled'].include?('events_map') && Rails.application.secrets.google_maps_api_key.present?
    end

    def _sentry_dsn
      ENV.fetch('SENTRY_DSN') { sentry_dsn }
    end

    def sentry_enabled?
      _sentry_dsn.present? && Rails.env.production?
    end
  end

  Config = TessConfig.new(tess_config)

  tess_base_uri = URI.parse(TeSS::Config.base_url)
  Rails.application.default_url_options = {
    host: tess_base_uri.host,
    port: tess_base_uri.port,
    protocol: tess_base_uri.scheme,
    script_name: (Rails.application.config.relative_url_root || '/')
  }
end
