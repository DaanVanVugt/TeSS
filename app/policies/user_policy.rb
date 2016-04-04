class UserPolicy < ApplicationPolicy

  def index?
    true
  end

  def show?
    # Anyone (not even logged in) can see users' pages, with restrictions in view
    # that owners and admins only can see their authentication token and email
    true
  end

  def create?
    # Do not allow creations via API and only admin role can create users
    !request_is_api?(request) and @user.is_admin?
  end

  def update?
    # Do not allow updates via API and only admin role can update anything
    # and owners can update their own record
    !request_is_api?(request) and (@user.is_owner?(@record) or @user.is_admin?)
  end

  class Scope < Scope
    def resolve
      User.all
    end
  end
end
