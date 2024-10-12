Pod::Spec.new do |s|
  s.name                  = 'pushy_flutter'
  s.version               = '2.0.28'
  s.summary               = 'The official Pushy SDK for Flutter iOS apps.'
  s.description           = 'Pushy is the most reliable push notification gateway, perfect for real-time, mission-critical applications.'
  s.homepage              = 'https://pushy.me/'

  s.author                = { 'Pushy' => 'contact@pushy.me' }
  s.license               = { :type => 'Apache-2.0', :file => 'LICENSE' }

  s.source                = { :path => '.' }
  s.source_files          = 'Classes/**/*'
  s.public_header_files   = 'Classes/**/*.h'

  s.dependency 'Flutter'
  s.dependency 'Pushy', '1.0.54'

  s.ios.deployment_target = '9.0'
end

