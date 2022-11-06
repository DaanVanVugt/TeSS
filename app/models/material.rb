require 'rails/html/sanitizer'

class Material < ApplicationRecord
  include PublicActivity::Common
  include LogParameterChanges
  include HasAssociatedNodes
  include HasExternalResources
  include HasContentProvider
  include HasLicence
  include LockableFields
  include Scrapable
  include Searchable
  include CurationQueue
  include HasSuggestions
  include IdentifiersDotOrg
  include HasFriendlyId
  include HasDifficultyLevel

  if TeSS::Config.solr_enabled
    # :nocov:
    searchable do
      # full text search fields
      text :title
      text :description
      text :contact
      text :doi
      text :authors
      text :contributors
      text :target_audience
      text :keywords
      text :resource_type
      text :content_provider do
        content_provider.try(:title)
      end
      # sort title
      string :sort_title do
        title.downcase.gsub(/^(an?|the) /, '')
      end
      # other fields
      string :title
      string :authors, multiple: true
      string :scientific_topics, multiple: true do
        scientific_topic_names
      end
      string :operations, multiple: true do
        operation_names
      end
      string :target_audience, multiple: true
      string :keywords, multiple: true
      string :fields, multiple: true
      string :resource_type, multiple: true
      string :contributors, multiple: true
      string :content_provider do
        content_provider.try(:title)
      end
      string :node, multiple: true do
        associated_nodes.map(&:name)
      end
      time :updated_at
      time :created_at
      time :last_scraped
      boolean :failing do
        failing?
      end
      string :user do
        user.username if user
      end
      integer :user_id # Used for shadowbans
      string :collections, multiple: true do
        collections.where(public: true).pluck(:title)
      end
    end
    # :nocov:
  end

  # has_one :owner, foreign_key: "id", class_name: "User"
  belongs_to :user
  has_one :link_monitor, as: :lcheck, dependent: :destroy
  has_many :collection_materials
  has_many :collections, through: :collection_materials
  has_many :event_materials, dependent: :destroy
  has_many :events, through: :event_materials

  has_ontology_terms(:scientific_topics, branch: OBO_EDAM.topics)
  has_ontology_terms(:operations, branch: OBO_EDAM.operations)

  has_many :stars, as: :resource, dependent: :destroy

  # Remove trailing and squeezes (:squish option) white spaces inside the string (before_validation):
  # e.g. "James     Bond  " => "James Bond"
  auto_strip_attributes :title, :description, :url, squish: false

  validates :title, :description, :url, presence: true
  validates :url, url: true
  validates :other_types, presence: true, if: proc { |m| m.resource_type.include?('other') }

  clean_array_fields(:keywords, :fields, :contributors, :authors,
                     :target_audience, :resource_type, :subsets)

  update_suggestions(:keywords, :contributors, :authors, :target_audience,
                     :resource_type)

  def description=(desc)
    super(Rails::Html::FullSanitizer.new.sanitize(desc))
  end

  def short_description=(desc)
    self.description = desc unless @_long_description_set
  end

  def long_description=(desc)
    @_long_description_set = true
    self.description = desc
  end

  def self.facet_fields
    field_list = %w[scientific_topics operations tools standard_database_or_policy content_provider keywords
                    difficulty_level fields licence target_audience authors contributors resource_type
                    related_resources user collections]

    field_list.delete('operations') if TeSS::Config.feature['disabled'].include? 'operations'
    field_list.delete('scientific_topics') if TeSS::Config.feature['disabled'].include? 'topics'
    field_list.delete('standard_database_or_policy') if TeSS::Config.feature['disabled'].include? 'fairshare'
    field_list.delete('tools') if TeSS::Config.feature['disabled'].include? 'biotools'
    field_list.delete('fields') if TeSS::Config.feature['disabled'].include? 'ardc_fields_of_research'
    field_list.delete('node') unless TeSS::Config.feature['nodes']
    field_list.delete('collections') unless TeSS::Config.feature['collections']

    field_list
  end

  def self.check_exists(material_params)
    given_material = new(material_params)
    material = nil

    material = find_by_url(given_material.url) if given_material.url.present?

    if given_material.content_provider.present? && given_material.title.present?
      material ||= where(content_provider_id: given_material.content_provider_id,
                         title: given_material.title).last
    end

    material
  end

  def to_bioschemas
    [Bioschemas::LearningResourceGenerator.new(self)]
  end
end
