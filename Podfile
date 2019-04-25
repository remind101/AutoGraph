platform :ios, '8.0'

# ignore all warnings from all pods
inhibit_all_warnings!
use_frameworks!

def jsonvalue
  pod 'JSONValueRX', '~> 5.0'
end

target 'AutoGraphQL' do
  pod 'Alamofire', '~> 4.8.2'
  jsonvalue
    
  target 'AutoGraphTests' do
    inherit! :complete
  end

  target 'QueryBuilderTests' do
    inherit! :complete
  end
end

target 'QueryBuilder' do
  jsonvalue
end

post_install do |installer|
  installer.pods_project.build_configurations.each do |config|
    if config.name.include?("Debug") or config.name.include?("Developer") or config.name.include?("Localhost")
      config.build_settings['GCC_OPTIMIZATION_LEVEL'] = '0'
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'DEBUG=1 RCT_DEBUG=1 RCT_DEV=1 RCT_NSASSERT=1'
    end
  end
end
