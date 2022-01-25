module Fastlane
  module Actions
    class IosMergeStringsFilesAction < Action
      def self.run(params)
        UI.message "Merging strings files: #{params[:paths].inspect}"

        duplicates = Fastlane::Helper::Ios::L10nHelper.merge_strings(paths: params[:paths], output_path: params[:destination])
        duplicates.each do |dup_key|
          UI.important "Duplicate key found while merging the `.strings` files: `#{dup_key}`"
        end
        duplicates
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        'Merge multiple `.strings` files into one'
      end

      def self.details
        <<~DETAILS
          Merge multiple `.strings` files into one.

          Especially useful to prepare a single `.strings` file merging strings from both `Localizable.strings` from
          the app code — typically previously extracted from `ios_generate_strings_file_from_code` —
          and string files like `InfoPlist.strings` — which values may not be generated from the codebase but
          manually maintained by developers.

          The action only supports merging files which are in the OpenStep (`"key" = "value";`) text format (which is
          the most common format for `.strings` files, and the one generated by `genstrings`), but can handle the case
          of different files using different encodings (UTF8 vs UTF16) and is able to detect and report duplicates.
          It does not handle strings files in XML or binary-plist formats `.strings` files (which are valid but more rare)
        DETAILS
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :paths,
            env_name: 'FL_IOS_MERGE_STRINGS_FILES_PATHS',
            description: 'The paths of all the `.strings` files to merge together',
            type: Array,
            optional: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :destination,
            env_name: 'FL_IOS_MERGE_STRINGS_FILES_DESTINATION',
            description: 'The path of the merged `.strings` file to generate. If nil, the merge will happen in-place in the first file in the `paths:` list',
            type: String,
            optional: true,
            default_value: nil
          ),
        ]
      end

      def self.return_type
        :array_of_strings
      end

      def self.return_value
        'The list of duplicate keys found while merging the various `.strings` files'
      end

      def self.authors
        ['automattic']
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
