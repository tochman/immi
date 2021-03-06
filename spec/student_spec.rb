describe Student do

  it { is_expected.to have_property :id }
  it { is_expected.to have_property :full_name }
  it { is_expected.to have_property :email }
  it { is_expected.to have_property :member_year }

  it { is_expected.to have_many_and_belong_to :memberships }
  it { is_expected.to have_many :certificates }
end