require './lib/membership'

describe Membership do
  it { is_expected.to have_property :id }
  it { is_expected.to have_property :title }
  it { is_expected.to have_property :description }

  it { is_expected.to have_many :students }
  it { is_expected.to have_many :certificates }
end
