module GitHelper
  def self.current_branch
    `git branch --show-current`.chomp
  end

  def self.check_or_create_branch(new_version)
    release_branch = "release/#{new_version}"
    if self.current_branch == release_branch
      puts 'Already on release branch'
    else
      sh('git', 'checkout', '-b', release_branch)
    end
  end

  def self.prepare_github_pr(head, base, title, body)
    require 'open-uri'
    qtitle = title.gsub(' ', '%20')
    qbody = body.gsub(' ', '%20')
    uri = "https://github.com/wordpress-mobile/release-toolkit/compare/#{base}...#{head}?expand=1&title=#{qtitle}&body=#{qbody}"
    Rake.sh('open', uri)
  end

  def self.commit_files(message, files, push: true)
    Rake.sh('git', 'add', *files)
    Rake.sh('git', 'commit', '-m', message)
    Rake.sh('git', 'push', 'origin', self.current_branch) if push
  end
end