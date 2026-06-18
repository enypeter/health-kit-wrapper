#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint health_kit_wrapper.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'health_kit_wrapper'
  s.version          = '1.0.0'
  s.summary          = 'Unified HealthKit / Health Connect plugin for Flutter.'
  s.description      = <<-DESC
One Dart API for permissions, aggregate/sample reads across 26 health data
types, and live change observation, backed by native HealthKit on iOS.
                       DESC
  s.homepage         = 'https://github.com/enypeter/health-kit-wrapper'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Damilare P Eniayewu' => 'enypieter@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.frameworks       = 'HealthKit'
  s.platform         = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
