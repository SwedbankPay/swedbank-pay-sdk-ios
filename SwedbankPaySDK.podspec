#
# Be sure to run `pod lib lint SwedbankPaySDK.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SwedbankPaySDK'
  s.version          = '1.0.0'
  s.summary          = 'Swedbank Pay SDK for iOS.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
The Swedbank Pay iOS SDK enables simple embedding of Swedbank Pay Checkout to an iOS application.
                       DESC

  s.homepage         = 'https://github.com/SwedbankPay'
  s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
  s.author           = { 'Swedbank AB' => 'example.email' }
  s.source           = { :git => 'https://github.com/SwedbankPay/swedbank-pay-sdk-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'
  s.swift_versions = '5.0'
  s.source_files = 'SwedbankPaySDK/Classes/**/*'
  
  s.frameworks = 'UIKit', 'WebKit'
  s.dependency 'Alamofire', '~> 4.9.0'
  s.dependency 'AlamofireObjectMapper', '~> 5.0'
end
