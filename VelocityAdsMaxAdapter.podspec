Pod::Spec.new do |s|
  s.name             = 'VelocityAdsMaxAdapter'
  s.version          = '0.10.0.0'
  s.summary          = 'AppLovin MAX custom-network adapter for the Velocity Ads iOS SDK.'
  s.description      = <<-DESC
    VelocityAdsMaxAdapter bridges the Velocity Ads iOS SDK into the AppLovin MAX
    mediation waterfall, supporting interstitial, rewarded, and native ad formats.
  DESC

  s.homepage         = 'https://github.com/velocityiodev/velocityads-ios-max-adapter'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author           = { 'Velocity Ads' => 'sdk@velocityads.io' }

  # Replace with actual GitHub release URL once tags are published.
  s.source           = {
    :git => 'https://github.com/velocityiodev/velocityads-ios-max-adapter.git',
    :tag => s.version.to_s
  }

  s.platform         = :ios, '13.0'
  s.swift_version    = '5.9'

  s.source_files     = 'Sources/VelocityAdsMaxAdapter/**/*.swift'

  s.dependency 'AppLovinSDK', '>= 13.0.0'
  s.dependency 'VelocityAdsSDK', '0.10.0'
end
