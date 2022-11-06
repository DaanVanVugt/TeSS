class CollectionPolicy < ResourcePolicy
  def update?
    super || @record.collaborator?(@user)
  end

  def show?
    @record.public? || manage?
  end

  def curate?
    TeSS::Config.feature['collection_curation'] && update?
  end

  def update_curation?
    curate?
  end

  class Scope < Scope
    def resolve
      Collection.visible_by(@user)
    end
  end
end
