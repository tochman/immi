require 'prawn'
require 'rmagick'
require 'aws-sdk'
if ENV['RACK_ENV'] != 'production'
  require 'dotenv'
end
require 'bitly'

module CertificateGenerator
  if ENV['RACK_ENV'] != 'production'
    Dotenv.load
  end
  Bitly.use_api_version_3
  CURRENT_ENV = ENV['RACK_ENV'] || 'development'
  PATH = "pdf/#{CURRENT_ENV}/"
  TEMPLATE = File.absolute_path('./pdf/templates/immi_bevis_2016.jpg')
  URL = ENV['SERVER_URL'] || 'http://localhost:9292/verify/'
  S3 = Aws::S3::Resource.new(region: ENV['AWS_REGION'])
  BITLY = Bitly.new(ENV['BITLY_USERNAME'], ENV['BITLY_API_KEY'])
  def self.generate(certificate)
    details = {name: certificate.student.full_name,
               date: certificate.delivery.start_date.to_s,
               course_name: certificate.delivery.course.title,
               course_desc: certificate.delivery.course.description,
               verify_url: [URL, certificate.identifier].join('')}

    file_name = [details[:name], details[:date], details[:course_name]].join('_').downcase.gsub!(/\s/, '_')

    certificate_output = "#{PATH}#{file_name}.pdf"
    image_output = "#{PATH}#{file_name}.jpg"

    make_prawn_document(details, certificate_output)
    make_rmagic_image(certificate_output, image_output)

    upload_to_s3(certificate_output, image_output)

    { certificate_key: certificate_output, image_key: image_output }

  end


  private

  def self.make_prawn_document(details, output)
    File.delete(output) if File.exist?(output)
    Prawn::Document.generate(output,
                             page_size: [210, 340],
                             background: TEMPLATE,
                             background_scale: 1,
                             page_layout: :landscape,
                             left_margin: 0,
                             right_margin: 0,
                             top_margin: 0,
                             bottom_margin: 0,
                             skip_encoding: true) do |pdf|
      pdf.move_down 80
      pdf.font 'assets/fonts/OpenSans-Bold.ttf'
      pdf.text details[:name], size: 20, align: :center
      pdf.move_down 15
      pdf.font 'assets/fonts/OpenSans-Regular.ttf'
      pdf.text details[:course_name], align: :center, size: 15
      pdf.move_down 50
      pdf.font 'assets/fonts/OpenSans-Light.ttf'
      pdf.text "Medlem sedan: " [:date], align: :left, size: 10, indent_paragraphs: 12
      pdf.text "Verifiera medlemsskapet: #{get_url(details[:verify_url])}", align: :left, size: 10, indent_paragraphs: 12
    
      end
  end

  def self.make_rmagic_image(certificate_output, output)
    im = Magick::Image.read(certificate_output)
    im[0].write(output)
  end

  def self.upload_to_s3(certificate_output, image_output)
    s3_certificate_object = S3.bucket(ENV['S3_BUCKET']).object(certificate_output)
    s3_certificate_object.upload_file(certificate_output, acl: 'public-read')
    s3_image_object = S3.bucket(ENV['S3_BUCKET']).object(image_output)
    s3_image_object.upload_file(image_output, acl: 'public-read')
  end
  

  def self.get_url(url)
    begin
      BITLY.shorten(url).short_url
    rescue
      url
    end
  end

end