require 'fastlane_core/ui/ui'
require 'octokit'
require 'open-uri'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?('UI')

  module Helper
    class GithubHelper
      def self.github_client
        client = Octokit::Client.new(access_token: ENV['GHHELPER_ACCESS'])

        # Fetch the current user
        user = client.user
        UI.message("Logged in as: #{user.name}")

        # Auto-paginate to ensure we're not missing data
        client.auto_paginate = true

        client
      end

      def self.get_milestone(repository, release)
        miles = github_client().list_milestones(repository)
        mile = nil

        miles&.each do |mm|
          mile = mm if mm[:title].start_with?(release)
        end

        return mile
      end

      # Fetch all the PRs for a given milestone
      #
      # @param [String] repository The repository name, including the organization (e.g. `wordpress-mobile/wordpress-ios`)
      # @param [String] milestone The name of the milestone we want to fetch the list of PRs for (e.g.: `16.9`)
      # @return [<Sawyer::Resource>] A list of the PRs for the given milestone, sorted by number
      #
      def self.get_prs_for_milestone(repository, milestone)
        github_client.search_issues(%(type:pr milestone:"#{milestone}" repo:#{repository}))[:items].sort_by(&:number)
      end

      def self.get_last_milestone(repository)
        options = {}
        options[:state] = 'open'

        milestones = github_client().list_milestones(repository, options)
        return nil if milestones.nil?

        last_stone = nil
        milestones.each do |mile|
          if last_stone.nil?
            last_stone = mile unless mile[:title].split(' ')[0].split('.').length < 2
          else
            begin
              if mile[:title].split(' ')[0].split('.')[0] > last_stone[:title].split(' ')[0].split('.')[0]
                last_stone = mile
              elsif mile[:title].split(' ')[0].split('.')[1] > last_stone[:title].split(' ')[0].split('.')[1]
                last_stone = mile
              end
            rescue StandardError
              puts 'Found invalid milestone'
            end
          end
        end

        last_stone
      end

      def self.create_milestone(repository, newmilestone_number, newmilestone_duedate, need_submission)
        submission_date = need_submission ? newmilestone_duedate.to_datetime.next_day(11) : newmilestone_duedate.to_datetime.next_day(14)
        release_date = newmilestone_duedate.to_datetime.next_day(14)
        comment = "Code freeze: #{newmilestone_duedate.to_datetime.strftime('%B %d, %Y')} App Store submission: #{submission_date.strftime('%B %d, %Y')} Release: #{release_date.strftime('%B %d, %Y')}"

        options = {}
        options[:due_on] = newmilestone_duedate
        options[:description] = comment
        github_client().create_milestone(repository, newmilestone_number, options)
      end

      def self.create_release(repository, version, release_notes, assets, prerelease)
        release = github_client().create_release(repository, version, name: version, draft: true, prerelease: prerelease, body: release_notes)
        assets.each do |file_path|
          github_client().upload_asset(release[:url], file_path, content_type: 'application/octet-stream')
        end
      end

      # Downloads a file from the given GitHub tag
      #
      # @param [String] repository The repository name (including the organization)
      # @param [String] tag The name of the tag we're downloading from
      # @param [String] file_path The path, inside the project folder, of the file to download
      # @param [String] download_folder The folder which the file should be downloaded into
      # @return [String] The path of the downloaded file, or nil if something went wrong
      #
      def self.download_file_from_tag(repository:, tag:, file_path:, download_folder:)
        repository = repository.delete_prefix('/').chomp('/').concat('/')
        file_path = file_path.delete_prefix('/').chomp('/').concat('/')
        tag = tag.concat('/')
        file_name = File.basename(file_path)
        download_path = File.join(download_folder, file_name)

        begin
          open(URI.join('https://raw.githubusercontent.com/', repository, tag, file_path).to_s.chomp('/')) do |remote_file|
            File.write(download_path, remote_file.read)
          end
        rescue OpenURI::HTTPError => ex
          return nil
        end

        download_path
      end
    end
  end
end