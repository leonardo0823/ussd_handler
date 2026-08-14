#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint ussd_handler.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'ussd_handler'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for executing USSD codes natively on iOS.'
  s.description      = <<-DESC
Flutter plugin for executing USSD codes on iOS devices. 
Provides basic functionality for USSD codes with iOS-specific limitations.
Includes system information and device capability verification.
                       DESC
  s.homepage         = 'https://github.com/tu-usuario/ussd_handler'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'USSD Handler Team' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # Privacy manifest for APIs that require justification
  s.resource_bundles = {'ussd_handler_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
