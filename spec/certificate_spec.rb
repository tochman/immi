describe Certificate do
  it { is_expected.to have_property :id }
  it { is_expected.to have_property :identifier }

  it { is_expected.to belong_to :membership }
  it { is_expected.to belong_to :student }

  it { is_expected.to have_property :certificate_key }
  it { is_expected.to have_property :image_key }

  describe 'Creating a Certificate' do
    before do
      membership = Membership.create(title: 'Learn To Code 101', description: 'Introduction to programming')
      student = membership.students.create(full_name: 'Thomas Ochman', email: 'thomas@random.com')
      @certificate = student.certificates.create(created_at: DateTime.now, membership: membership)
    end
    after do
      FileUtils.rm_rf Dir['pdf/test/**/*.pdf']
    end
    it 'adds an identifier after create' do
      expect(@certificate.identifier.size).to eq 64
    end
    it 'has a Student name' do
      expect(@certificate.student.full_name).to eq 'Thomas Ochman'
    end
    it 'has a Course name' do
      expect(@certificate.membership.title).to eq 'Learn To Code 101'
    end
    it 'returns #bitly_lookup' do
      expect(@certificate.bitly_lookup).to eq "http://localhost:9292/verify/#{@certificate.identifier}"
    end
    it 'returns #stats' do
      expect(@certificate.stats).to eq 0
    end

    describe 'S3' do
      before do
        keys = CertificateGenerator.generate(@certificate)
        @certificate.update(certificate_key: keys[:certificate_key], image_key: keys[:image_key])
      end
      it 'can be fetched by #image_url' do
        expect(@certificate.image_url).to eq 'https://certz.s3.amazonaws.com/pdf/test/thomas_ochman_2015-01-01_learn_to_code_101.jpg'
      end
      it 'can be fetched by #certificate_url' do
        expect(@certificate.certificate_url).to eq 'https://certz.s3.amazonaws.com/pdf/test/thomas_ochman_2015-01-01_learn_to_code_101.pdf'
      end
    end
  end
end
