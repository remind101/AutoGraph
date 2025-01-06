#
# Be sure to run `pod lib lint AutoGraph.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "AutoGraph"
  s.module_name      = "AutoGraphQL"
  s.version          = "0.16.2"
  s.summary          = "Swift GraphQL Client and Mapping library with Realm support"

  s.description      = <<-DESC
  A flexible Swift framework for requesting and mapping data from a GraphQL server with support for storage solutions such as Realm.
                       DESC

  s.homepage         = "https://github.com/remind101/AutoGraph"
  s.license          = 'MIT'
  s.author           = { "rexmas" => "rex@remindhq.com" }
  s.source           = { :git => "https://github.com/remind101/AutoGraph.git", :tag => s.version.to_s }

  s.platform     = :ios, '13.0'
  s.swift_version = '5.9'
  s.requires_arc = true

  s.dependency 'Alamofire', '~> 5.8.0'
  s.dependency 'JSONValueRX', '~> 8.0'
  s.dependency 'Starscream', '= 4.0.4'
  
  s.source_files = 'AutoGraph/**/*.swift', 'QueryBuilder/**/*.swift'
  s.resource_bundles = {
  }

end
