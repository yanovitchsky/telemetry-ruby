Gem::Specification.new do |s|
  s.name = 'telemetry'
  s.version = '0.0.1'
  s.date = '2013-08-08'
  s.summary = ""
  s.description = ""
  s.authors = ["Ryan Kennedy"]
  s.email = 'rkennedy@yammer-inc.com'
  s.files = ["lib/telemetry.rb"]
  s.homepage = 'https://github.com/yammer/telemetry'
  s.license = 'Apache 2.0'
  s.add_dependency 'multi_json', '~> 1.0'
  s.add_dependency('sinatra')
  s.add_dependency('mongoid')
  s.add_dependency('em-mongo')
  s.add_dependency('redis')
end