desc 'build and run tests'
task :test do
  sh "dub test"
end

task :run do
  sh "dub run -- rebase --interactive - something else"
  sh "dub run -- rebase - something else"
end
task :default => ['test', 'run']
