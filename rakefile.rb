desc 'build and run tests'
task :test do
  sh "dub clean"
  sh "dub test"
end

task :run do
  sh "dub clean"
  sh "dub run -- --message=m --logLevel=3 add --interactive=5 - something else"
end
task :default => ['test', 'run']
