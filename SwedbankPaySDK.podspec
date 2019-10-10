#
# Be sure to run `pod lib lint SwedbankPaySDK.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SwedbankPaySDK'
  s.version          = '0.1.0'
  s.summary          = 'Swedbank Pay SDK for iOS.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Swedbank Pay SDK for iOS.
                       DESC

  s.homepage         = 'https://github.com/SwedbankPay'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
  s.author           = { 'Swedbank AB' => 'example.email' }
  s.source           = { :git => 'https://github.com/swedbank/SwedbankPaySDK.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '9.0'

  s.source_files = 'SwedbankPaySDK/Classes/**/*'
  
  # s.resources = 'SwedbankPaySDK/Assets/*.xcassets'
  # s.resource_bundles = {
  #  'PayexSDK' => ['SwedbankPaySDK/Assets/**/*.png']
  # }
  # s.resource = 'Pod/Resources/**/*.png'

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'UIKit', 'WebKit'
  s.dependency 'Alamofire', '~> 4.9.0'
  s.dependency 'AlamofireObjectMapper', '~> 5.0'
end
