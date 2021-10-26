# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "yard"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

YARD::Rake::YardocTask.new do |t|
  t.files = ["lib/**/*.rb"]
  t.options = []
  t.stats_options = ["--list-undoc"]
end

desc "Version up"
task :versionup do
  version = ""
  File.open("./lib/mizlab/version.rb") do |f|
    version = f.read[(/(\d+\.\d+\.\d+)/)]
  end
  ver, minor_ver, hotfix = version.split(".")
  hotfix = hotfix.to_i + 1
  new_version = "#{ver}.#{minor_ver}.#{hotfix}"
  cmd = "sed -E -i 's/[0-9]+\\.[0-9]+\\.[0-9]+/#{new_version}/' ./lib/mizlab/version.rb"
  puts(cmd)
  system(cmd)
  cmd = "git add ./lib/mizlab/version.rb && git commit -m ':rocket: Version up'"
  puts(cmd)
  system(cmd)
  cmd = "git tag v#{new_version}"
  puts(cmd)
  system(cmd)
end

task default: :test
