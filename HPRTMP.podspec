Pod::Spec.new do |s|
  s.name             = 'HPRTMP'
  s.version          = '0.0.3'
  s.summary          = 'A library for Real-Time Messaging Protocol (RTMP) streaming in Swift.'
  s.homepage         = 'https://github.com/huiping192/HPRTMP'
  s.license          = 'MIT'
  s.author           = { 'huiping192' => 'huiping192@163.com' }
  s.platforms        = { :ios => '13.0', :osx => '10.15' }
  s.source           = { :git => 'https://github.com/huiping192/HPRTMP.git', :tag => s.version.to_s }
  s.swift_version    = '5.5'
  
  s.source_files = 'Sources/**/*.swift'
  
  s.frameworks = "Foundation","Network"
end
