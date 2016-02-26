class Membership
  include DataMapper::Resource

  property :id, Serial
  property :title, String
  property :description, Text

  has n, :students
  has n, :certificates, through: :students

end