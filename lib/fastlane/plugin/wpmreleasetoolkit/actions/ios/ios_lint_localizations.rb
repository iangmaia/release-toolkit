module Fastlane
    module Actions
      class IosLintLocalizationsAction < Action
        def self.run(params)
          UI.message "Linting localizations for parameter placeholders consistency..."
    
          require_relative '../../helper/ios/ios_l10n_helper.rb'
          helper = Fastlane::Helpers::IosL10nHelper.new(
            install_path: resolve_path(params[:install_path]),
            version: params[:version]
          )
          violations = helper.run(
            input_dir: resolve_path(params[:input_dir]),
            base_lang: params[:base_lang],
          )
        
          violations.each do |lang, diff|
            UI.error "Inconsistencies found between '#{params[:base_lang]}' and '#{lang}':\n\n#{diff}\n"
          end
          if params[:abort_on_violations] && !violations.empty?
            UI.abort_with_message!('Inconsistencies found during Localization linting. Aborting.')
          end
          
          violations
        end

        def self.repo_root
          @repo_root || `git rev-parse --show-toplevel`.chomp
        end

        # If the path is relative, makes the path absolute by resolving it relative to the repository's root.
        # If the path is already absolute, it will not affect it and return it as-is.
        def self.resolve_path(path)
          File.absolute_path(path, repo_root)
        end
    
        #####################################################
        # @!group Documentation
        #####################################################
    
        def self.description
          "Lint the different *.lproj/.strings files for each locale and ensure the parameter placeholders are consistent."
        end
    
        def self.details
          "Compares the translations against a base language to find potential mismatches for the %s/%d/… parameter placeholders between locales."
        end
    
        def self.available_options
          [
            FastlaneCore::ConfigItem.new(
              key: :install_path,
              env_name: "FL_IOS_LINT_TRANSLATIONS_INSTALL_PATH",
              description: "The path where to install the SwiftGen tooling needed to run the linting process. If a relative path, should be relative to your repo_root",
              type: String,
              optional: true,
              default_value: "vendor/swiftgen/#{Fastlane::Helpers::IosL10nHelper::SWIFTGEN_VERSION}"
            ),
            FastlaneCore::ConfigItem.new(
              key: :version,
              env_name: "FL_IOS_LINT_TRANSLATIONS_SWIFTGEN_VERSION",
              description: "The version of SwiftGen to install and use for linting",
              type: String,
              optional: true,
              default_value: Fastlane::Helpers::IosL10nHelper::SWIFTGEN_VERSION
            ),
            FastlaneCore::ConfigItem.new(
              key: :input_dir,
              env_name: "FL_IOS_LINT_TRANSLATIONS_INPUT_DIR",
              description: "The path to the directory containing the .lproj folders to lint, relative to your git repo root",
              type: String,
              optional: false
            ),
            FastlaneCore::ConfigItem.new(
              key: :base_lang,
              env_name: "FL_IOS_LINT_TRANSLATIONS_BASE_LANG",
              description: "The language that should be used as the base language that every other language will be compared against",
              type: String,
              optional: true,
              default_value: Fastlane::Helpers::IosL10nHelper::DEFAULT_BASE_LANG
            ),
            FastlaneCore::ConfigItem.new(
              key: :abort_on_violations,
              env_name: "FL_IOS_LINT_TRANSLATIONS_ABORT",
              description: "Should we abort the rest of the lane with a global error if any violations are found?",
              optional: true,
              default_value: true,
              is_string: false # https://docs.fastlane.tools/advanced/actions/#boolean-parameters
            ),
          ]
        end
    
        def self.output
          nil
        end
    
        def self.return_type
          :hash_of_strings
        end

        def self.return_value
          "A hash, keyed by language code, whose values are the diff found for said language"
        end
    
        def self.authors
          ["AliSoftware"]
        end
    
        def self.is_supported?(platform)
          [:ios, :mac].include?(platform)
        end
      end
    end
  end