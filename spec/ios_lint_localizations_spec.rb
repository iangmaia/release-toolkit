require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require 'yaml'

describe Fastlane::Actions::IosLintLocalizationsAction do
  before do
    # Ensure `Action.sh` is not skipped during test – so that SwiftGen will be installed by our action as normal – See spec_helper.rb
    allow_fastlane_action_sh()
  end

  context 'SwiftGen Installation Logic' do
    it 'only installs SwiftGen the first time, when it is not yet installed' do
      Dir.mktmpdir('a8c-lint-l10n-tests-swiftgen-install-') do |install_dir|
        Dir.mktmpdir('a8c-lint-l10n-tests-data-') do |empty_dataset|
          # Expect install dir to be empty before we start
          expect(Dir.empty?(install_dir)).to be true

          # First run: expect curl, unzip and cp_r to be called to install SwiftGen before running the action
          # See spec_helper.rb for documentation about `expect_shell_command`.
          expect_shell_command('curl', any_args, %r{/.*swiftgen-#{Fastlane::Helper::Ios::L10nLinterHelper::SWIFTGEN_VERSION}.zip})
          expect_shell_command('unzip', any_args)
          expect(FileUtils).to receive(:cp_r)
          expect_shell_command("#{install_dir}/bin/swiftgen", 'config', 'run', '--config', anything)

          run_described_fastlane_action(
            install_path: install_dir,
            input_dir: empty_dataset,
            base_lang: 'en'
          )

          # Create a fake SwiftGen binstub to simulate SwiftGen has been installed at that point
          script = <<~SCRIPT
            #!/bin/sh
            if [[ "$1" == "--version" ]]; then
              echo "SwiftGen v#{Fastlane::Helper::Ios::L10nLinterHelper::SWIFTGEN_VERSION} (Fake binstub)"
            fi
          SCRIPT
          FileUtils.mkdir_p File.join(install_dir, 'bin')
          # NOTE: `0o` is octal notation, used to specify chmod-like flags
          File.write(File.join(install_dir, 'bin/swiftgen'), script, perm: 0o766)

          # Second run: ensure we only run SwiftGen directly, without a call to curl nor unzip beforehand
          expect_shell_command("#{install_dir}/bin/swiftgen", 'config', 'run', '--config', anything)

          run_described_fastlane_action(
            install_path: install_dir,
            input_dir: empty_dataset,
            base_lang: 'en'
          )
        end
      end
    end
  end

  context 'Linter' do
    # Helper function that DRYs the code running each test.
    #
    # @param [String] data_file The name, without extension or "test-lint-ios-" prefix, of the YML file containing the test input and expected output.
    # @param [Bool|nil] check_duplicate_keys If `nil`, the test will run the action with the default `check_duplicate_keys` parameter value.
    #        If a `Bool` value is given, it will pass that.
    #        Using either `Bool` or `nil` adds some cruft, but lets us validate the action default behavior, so it doesn't change unexpectedly.
    #
    def run_l10n_linter_test(data_file:, check_duplicate_keys: nil)
      # Arrange: Prepare test files
      test_file = File.join(File.dirname(__FILE__), 'test-data', 'translations', 'ios_lint_localizations', "#{data_file}.yaml")
      yml = YAML.load_file(test_file)

      files = yml['test_data']
      files.each do |lang, content|
        lproj = File.join(@test_data_dir, "#{lang}.lproj")
        FileUtils.mkdir_p(lproj)
        File.write(File.join(lproj, 'Localizable.strings'), content) unless content.nil?
      end

      # Act
      # Note: We will install SwiftGen in vendor/swiftgen if it's not already installed yet, and intentionally won't
      #       remove this after the test ends, so that further executions of the test run faster.
      #       Only the first execution of the tests might take longer if it needs to install SwiftGen first to be able to run the tests.
      install_dir = "vendor/swiftgen/#{Fastlane::Helper::Ios::L10nLinterHelper::SWIFTGEN_VERSION}"
      parameters = {
        install_path: install_dir,
        input_dir: @test_data_dir,
        base_lang: 'en'
      }
      parameters[:check_duplicate_keys] = check_duplicate_keys unless check_duplicate_keys.nil?
      result = run_described_fastlane_action(parameters)

      # Assert
      expect(result).to eq(yml['result'])
    end

    before(:each) do
      @test_data_dir = Dir.mktmpdir('a8c-lint-l10n-tests-data-')
      allow(FastlaneCore::UI).to receive(:abort_with_message!)
    end

    it 'succeeds when there are no violations' do
      run_l10n_linter_test(data_file: 'no-violations')
    end

    it 'detects inconsistent placeholder count' do
      run_l10n_linter_test(data_file: 'wrong-placeholder-count')
    end

    it 'detects inconsistent placeholder types' do
      run_l10n_linter_test(data_file: 'wrong-placeholder-types')
    end

    it 'properly handles misleading characters and placeholders in RTL languages' do
      run_l10n_linter_test(data_file: 'tricky-chars')
    end

    it 'detects both inconsistencies and duplicated strings by default' do
      # "by default" = don't explicitly set the `:check_duplicate_keys` parameter
      run_l10n_linter_test(data_file: 'violations-and-duplicate-keys')
    end

    it 'detects when there are only duplications and reports them' do
      run_l10n_linter_test(data_file: 'duplicate-keys-only')
    end

    it 'detects both inconsistencies and duplicated strings when asked to do so' do
      run_l10n_linter_test(data_file: 'violations-and-duplicate-keys', check_duplicate_keys: true)
    end

    it 'ignores duplicated strings when asked to do so' do
      run_l10n_linter_test(data_file: 'violations-and-duplicate-keys-reporting-violations-only', check_duplicate_keys: false)
    end

    it 'does not fail if a locale does not have any Localizable.strings' do
      run_l10n_linter_test(data_file: 'no-strings')
    end

    it 'allows to retry after manual fix' do
      # Arrange: Prepare test files
      valid_content = <<~FIXED_CONTENT
        "string_placeholder" = "String %@ here.";
      FIXED_CONTENT

      invalid_content = <<~INVALID_CONTENT
        "string_placeholder" = "Int %d here.";
      INVALID_CONTENT

      en_lproj = File.join(@test_data_dir, 'en.lproj')
      FileUtils.mkdir_p(en_lproj)
      File.write(File.join(en_lproj, 'Localizable.strings'), valid_content)

      fr_lproj = File.join(@test_data_dir, 'fr.lproj')
      FileUtils.mkdir_p(fr_lproj)
      File.write(File.join(fr_lproj, 'Localizable.strings'), invalid_content)

      # Assert: Ask to retry after first failure reported and simulated manual fix in between
      expect(FastlaneCore::UI).to receive(:error).once
      expect(FastlaneCore::UI).to receive(:confirm) do
        # Simulate manual fix between the confirm prompt being asked and replying to it
        File.write(File.join(fr_lproj, 'Localizable.strings'), valid_content)
        true
      end

      # Act
      install_dir = "vendor/swiftgen/#{Fastlane::Helper::Ios::L10nLinterHelper::SWIFTGEN_VERSION}"
      result = run_described_fastlane_action(
        install_path: install_dir,
        input_dir: @test_data_dir,
        base_lang: 'en',
        allow_retry: true
      )

      # Assert
      expect(result).to eq({}) # No violations anymore after manual fix and first retry
    end

    it 'warns if input files are not in ASCII-plist format' do
      # Arrange: Prepare test files
      en_lproj = File.join(@test_data_dir, 'en.lproj')
      ascii_file = File.join(File.dirname(__FILE__), 'test-data', 'translations', 'ios_l10n_helper', 'Localizable-utf16.strings')
      FileUtils.mkdir_p(en_lproj)
      File.write(File.join(en_lproj, 'Localizable.strings'), File.read(ascii_file))

      fr_lproj = File.join(@test_data_dir, 'fr.lproj')
      xml_file = File.join(File.dirname(__FILE__), 'test-data', 'translations', 'ios_l10n_helper', 'xml-format.strings')
      FileUtils.mkdir_p(fr_lproj)
      File.write(File.join(fr_lproj, 'Localizable.strings'), File.read(xml_file))

      expected_message = <<~EXPECTED_WARNING
        File `#{fr_lproj}/Localizable.strings` is in xml format, while finding duplicate keys only make sense on files that are in ASCII-plist format.
        Since your files are in xml format, you should probably disable the `check_duplicate_keys` option from this `ios_lint_localizations` call.
      EXPECTED_WARNING
      expect(FastlaneCore::UI).to receive(:important).with(expected_message)

      # Act
      install_dir = "vendor/swiftgen/#{Fastlane::Helper::Ios::L10nLinterHelper::SWIFTGEN_VERSION}"
      result = run_described_fastlane_action(
        install_path: install_dir,
        input_dir: @test_data_dir,
        base_lang: 'en'
      )

      expect(result).to eq({ 'fr' => ['`key3` expected placeholders for [Int] but found [] instead.'] })
    end

    after(:each) do
      FileUtils.remove_entry @test_data_dir
    end
  end
end
