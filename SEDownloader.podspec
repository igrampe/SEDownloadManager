#
# Be sure to run `pod lib lint SEDownloader.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SEDownloader'
  s.version          = '0.1.0'
  s.summary          = 'A short description of SEDownloader.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/igrampe/SEDownloader'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'igrampe' => 'igrampe@gmail.com' }
  s.source           = { :git => 'https://github.com/igrampe/SEDownloader.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'SEDownloader/Classes/**/*'
  
  # s.resource_bundles = {
  #   'SEDownloader' => ['SEDownloader/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'REDownloadTasksQueue', '~> 1.1'
  s.dependency 'Realm', '~> 2.5.1'

  s.frameworks = 'Realm', 'REDownloadTasksQueue'
end
