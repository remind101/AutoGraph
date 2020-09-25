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
  s.version          = "0.13.0"
  s.summary          = "Swift GraphQL Client and Mapping library with Realm support"

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!
  s.description      = <<-DESC
  A flexible Swift framework for requesting and mapping data from a GraphQL server with support for storage solutions such as Realm.
                       DESC

  s.homepage         = "https://github.com/remind101/AutoGraph"
  s.license          = 'MIT'
  s.author           = { "rexmas" => "rex@remindhq.com" }
  s.source           = { :git => "https://github.com/remind101/AutoGraph.git", :tag => s.version.to_s }

  s.platform     = :ios, '10.0'
  s.requires_arc = true

  s.dependency 'Alamofire', '~> 5.0.5'
  s.dependency 'JSONValueRX', '~> 7.0.0'
  s.dependency 'Starscream', '~> 4.0.0'
  
  s.source_files = 'AutoGraph/**/*.swift', 'QueryBuilder/**/*.swift'
  s.resource_bundles = {
  }

end
