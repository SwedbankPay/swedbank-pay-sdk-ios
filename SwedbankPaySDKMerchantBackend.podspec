Pod::Spec.new do |s|
  s.name             = 'SwedbankPaySDKMerchantBackend'
  s.version          = ENV['RELEASE_TAG_NAME'] || '0.1-local'
  s.summary          = 'Swedbank Pay SDK Merchant Backend additions for iOS.'

  s.description      = <<-DESC
This pod contains utilities for easy interfacing of the Swedbank Pay SDK with
a backend server that implements the Merchant Backend API.
                       DESC

  s.homepage         = 'https://github.com/SwedbankPay/swedbank-pay-sdk-ios'
  s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
  s.author           = 'Swedbank Pay'
  s.source           = { :git => 'https://github.com/SwedbankPay/swedbank-pay-sdk-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'
  s.swift_versions = '5.0', '5.1'
  
  s.dependency 'SwedbankPaySDK', s.version.to_s
  s.dependency 'Alamofire', '~> 5.4'

  s.source_files = 'SwedbankPaySDKMerchantBackend/Classes/**/*'
end
