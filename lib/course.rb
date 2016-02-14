class Course
  include DataMapper::Resource

  property :id, Serial
  property :title, String
  property :description, Text

  has n, :deliveries
  get("/:id/delete") {|id| @course = Course.get id; erb :delete }
end
