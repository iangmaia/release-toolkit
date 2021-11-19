require 'open3'

module Fastlane
  module Actions
    class IosGenerateStringsFileFromCode < Action
      def self.run(params)
        globbed_paths = params[:paths].map { |p| File.file?(p) ? p : "#{p}/**/*.{m,swift}" }
        files = Dir.glob(globbed_paths)

        flags = [('-q' if params[:quiet]), ('-SwiftUI' if params[:swiftui])].compact

        out, status = Open3.capture2e('genstrings', '-o', params[:output_dir], *flags, *files)

        UI.error("genstrings failed with exit code #{status.exitstatus}") unless status.success?
        UI.command_output(out) unless params[:quiet]

        # Return the warnings as an Array
        out.split("\n")
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        'Generate the .strings files from your Objective-C and Swift code'
      end

      def self.details
        'Use genstrings to generate the .strings files from your Objective-C and Swift code.'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :paths,
                                       env_name: 'FL_IOS_GENERATE_STRINGS_FILE_FROM_CODE_PATHS',
                                       description: 'Array of directory paths to scan for `.m` and `.swift` files. The entries can contain glob patterns too',
                                       type: Array,
                                       default_value: ['.']),
          FastlaneCore::ConfigItem.new(key: :quiet,
                                       env_name: 'FL_IOS_GENERATE_STRINGS_FILE_FROM_CODE_QUIET',
                                       description: 'In quiet mode, genstrings will log warnings about duplicate values, but not about duplicate comments',
                                       is_string: false, # Boolean
                                       default_value: true),
          FastlaneCore::ConfigItem.new(key: :swiftui,
                                       env_name: 'FL_IOS_GENERATE_STRINGS_FILE_FROM_CODE_SWIFTUI',
                                       description: "Should we include SwiftUI's `Text()` when parsing code with `genstrings`",
                                       is_string: false, # Boolean
                                       default_value: true),
          FastlaneCore::ConfigItem.new(key: :output_dir,
                                       env_name: 'FL_IOS_GENERATE_STRINGS_FILE_FROM_CODE_OUTPUT_DIR',
                                       description: 'The path to the directory where the generated .strings files should be created',
                                       type: String),
        ]
      end

      def self.output
        ['Generates .strings files (especially Localizable.strings but could generate more if the code uses custom tables)']
      end

      def self.return_value
        'List of warnings generated by genstrings on stdout'
      end

      def self.authors
        ['Automattic']
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
