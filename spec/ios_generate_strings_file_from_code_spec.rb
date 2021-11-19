require 'spec_helper'
require 'tmpdir'

describe Fastlane::Actions::IosGenerateStringsFileFromCode do
  let(:test_data_dir) { File.join(File.dirname(__FILE__), 'test-data', 'translations', 'ios_generate_strings_file_from_code') }
  let(:app_src_dir) { File.join(test_data_dir, 'sample-project', 'Sources') }
  let(:pods_src_dir) { File.join(test_data_dir, 'sample-project', 'Pods') }

  def test_genstrings(paths_to_scan:, quiet:, swiftui:, expected_dir_name:, expected_logs: nil)
    # Arrange
    allow_fastlane_action_sh # see spec_helper
    cmd_output = []
    allow(FastlaneCore::UI).to receive(:command_output) { |line| cmd_output << line }

    Dir.mktmpdir('a8c-wpmrt-ios_generate_strings_file_from_code-') do |tmp_dir|
      # Act
      return_value = described_class.run(paths: paths_to_scan, quiet: quiet, swiftui: swiftui, output_dir: tmp_dir)

      output_files = Dir[File.join(tmp_dir, '*.strings')]
      expected_files = Dir[File.join(test_data_dir, expected_dir_name, '*.strings')]

      # Assert: UI.messages and return value from the action
      unless expected_logs.nil?
        expect(cmd_output).to eq(expected_logs)
        expect(return_value).to eq(expected_logs)
      end
      # Assert: same list of generated files
      expect(output_files.map { |f| File.basename(f) }.sort).to eq(expected_files.map { |f| File.basename(f) }.sort)

      # Assert: each generated file has expected content
      output_files.each do |generated_file|
        file_basename = File.basename(generated_file)
        expected_file = expected_files.find { |f| File.basename(f) == file_basename }
        expect(File.read(generated_file)).to eq(File.read(expected_file)), "Content of '#{file_basename}' and '#{expected_file}' do not match."
      end
    end
  end

  context 'when including pods' do
    it 'Generates the expected .strings files with SwiftUI support' do
      test_genstrings(paths_to_scan: [app_src_dir, pods_src_dir], quiet: true, swiftui: true, expected_dir_name: 'expected-pods-swiftui')
    end

    it 'Generates the expected .strings files without SwiftUI support' do
      test_genstrings(paths_to_scan: [app_src_dir, pods_src_dir], quiet: true, swiftui: false, expected_dir_name: 'expected-pods-noswiftui')
    end
  end

  context 'when not including pods' do
    it 'Generates the expected .strings files with SwiftUI support' do
      test_genstrings(paths_to_scan: [app_src_dir], quiet: true, swiftui: true, expected_dir_name: 'expected-nopods-swiftui')
    end

    it 'Generates the expected .strings files without SwiftUI support' do
      test_genstrings(paths_to_scan: [app_src_dir], quiet: true, swiftui: false, expected_dir_name: 'expected-nopods-noswiftui')
    end
  end

  context 'when genstrings finds warnings' do
    it 'only logs warnings about multiple values in quiet mode' do
      expected_logs = [
        %(Key "app.key5" used with multiple values. Value "app value 5\\nwith multiple lines." kept. Value "app value 5\\nwith multiple lines, and different value than in Swift" ignored.),
      ]
      test_genstrings(
        paths_to_scan: [app_src_dir, pods_src_dir],
        quiet: true,
        swiftui: true,
        expected_dir_name: 'expected-pods-swiftui',
        expected_logs: expected_logs
      )
    end

    it 'logs warnings about both multiple values and multiple comments if not in quiet mode' do
      expected_logs = [
        %(Key "app.key5" used with multiple values. Value "app value 5\\nwith multiple lines." kept. Value "app value 5\\nwith multiple lines, and different value than in Swift" ignored.),
        %(genstrings: warning: Key "app.key5" used with multiple comments "App key 5, with value, custom table and placeholder." & "Duplicate declaration of App key 5 between ObjC and Swift,and with a comment even spanning multiple lines!"),
        %(genstrings: warning: Key "pod.key5" used with multiple comments "Duplicate declaration of Pod key 5 between ObjC and Swift,and with a comment even spanning multiple lines!" & "Pod key 5, with value, custom table and placeholder."),
      ]
      test_genstrings(
        paths_to_scan: [app_src_dir, pods_src_dir],
        quiet: false,
        swiftui: true,
        expected_dir_name: 'expected-pods-swiftui',
        expected_logs: expected_logs
      )
    end
  end
end
