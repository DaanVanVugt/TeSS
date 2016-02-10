class Package < ActiveRecord::Base
	include PublicActivity::Common
  has_paper_trail

  extend FriendlyId
  friendly_id :name, use: :slugged

	has_many :package_materials
  has_many :package_events
	has_many :materials, through: :package_materials
  has_many :events, through: :package_events

	has_one :owner, foreign_key: "id", class_name: "User"

  clean_array_fields(:keywords)

  after_save :log_activities

  unless SOLR_ENABLED==false
    searchable do 
      text :name
      text :description
      string :owner do
      	self.owner.username.to_s if !owner.nil?
      end
      string :keywords, :multiple => true
      
      string :creator, :multiple => true do
        if self.owner
          if self.owner.profile and (self.owner.profile.firstname or self.owner.profile.surname)
            "#{self.owner.profile.firstname} #{self.owner.profile.surname}"
          else
            self.owner.username
          end
        end
        end
      end
  end
  
  def log_activities
    self.changed.each do |changed_attribute|
      #TODO: Sort out what gets logged
      # If content provider - find content provider otherwise uses ID.
      #     maybe add new activity for content provider having a new material added to it too.
      # If updated at - ignore
      self.create_activity :update_parameter, parameters: {attr: changed_attribute, new_val: self.send(changed_attribute)}
    end
  end
end
