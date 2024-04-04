# frozen_string_literal: true

require "open3"
require "pathname"

require_relative "user"

module Datadog
  module CI
    module Git
      module LocalRepository
        def self.root
          return @root if defined?(@root)

          @root = git_root || Dir.pwd
        rescue => e
          Datadog.logger.debug(
            "Unable to read git root: #{e.class.name} #{e.message} at #{Array(e.backtrace).first}"
          )
          @root = Dir.pwd
        end

        def self.relative_to_root(path)
          return "" if path.nil?

          root_path = root
          return path if root_path.nil?

          path = Pathname.new(File.expand_path(path))
          root_path = Pathname.new(root_path)

          path.relative_path_from(root_path).to_s
        end

        def self.repository_name
          return @repository_name if defined?(@repository_name)

          git_remote_url = git_repository_url

          # return git repository name from remote url without .git extension
          last_path_segment = git_remote_url.split("/").last if git_remote_url
          @repository_name = last_path_segment.gsub(".git", "") if last_path_segment
          @repository_name ||= current_folder_name
        rescue => e
          Datadog.logger.debug(
            "Unable to get git remote: #{e.class.name} #{e.message} at #{Array(e.backtrace).first}"
          )
          @repository_name = current_folder_name
        end

        def self.current_folder_name
          File.basename(root)
        end

        def self.git_repository_url
          exec_git_command("git ls-remote --get-url")
        rescue => e
          Datadog.logger.debug(
            "Unable to read git repository url: #{e.class.name} #{e.message} at #{Array(e.backtrace).first}"
          )
          nil
        end

        def self.git_root
          exec_git_command("git rev-parse --show-toplevel")
        rescue => e
          Datadog.logger.debug(
            "Unable to read git root path: #{e.class.name} #{e.message} at #{Array(e.backtrace).first}"
          )
          nil
        end

        def self.git_commit_sha
          exec_git_command("git rev-parse HEAD")
        rescue => e
          Datadog.logger.debug(
            "Unable to read git commit SHA: #{e.class.name} #{e.message} at #{Array(e.backtrace).first}"
          )
          nil
        end

        def self.git_branch
          exec_git_command("git rev-parse --abbrev-ref HEAD")
        rescue => e
          Datadog.logger.debug(
            "Unable to read git branch: #{e.class.name} #{e.message} at #{Array(e.backtrace).first}"
          )
          nil
        end

        def self.git_tag
          exec_git_command("git tag --points-at HEAD")
        rescue => e
          Datadog.logger.debug(
            "Unable to read git tag: #{e.class.name} #{e.message} at #{Array(e.backtrace).first}"
          )
          nil
        end

        def self.git_commit_message
          exec_git_command("git show -s --format=%s")
        rescue => e
          Datadog.logger.debug(
            "Unable to read git commit message: #{e.class.name} #{e.message} at #{Array(e.backtrace).first}"
          )
          nil
        end

        def self.git_commit_users
          # Get committer and author information in one command.
          output = exec_git_command("git show -s --format='%an\t%ae\t%at\t%cn\t%ce\t%ct'")
          unless output
            Datadog.logger.debug(
              "Unable to read git commit users: git command output is nil"
            )
            nil_user = NilUser.new
            return [nil_user, nil_user]
          end

          author_name, author_email, author_timestamp,
            committer_name, committer_email, committer_timestamp = output.split("\t").each(&:strip!)

          author = User.new(author_name, author_email, author_timestamp)
          committer = User.new(committer_name, committer_email, committer_timestamp)

          [author, committer]
        rescue => e
          Datadog.logger.debug(
            "Unable to read git commit users: #{e.class.name} #{e.message} at #{Array(e.backtrace).first}"
          )
          nil_user = NilUser.new
          [nil_user, nil_user]
        end

        # makes .exec_git_command private to make sure that this method
        # is not called from outside of this module with insecure parameters
        class << self
          private

          def exec_git_command(cmd)
            # Shell injection is alleviated by making sure that no outside modules call this method.
            # It is called only internally with static parameters.
            # no-dd-sa:ruby-security/shell-injection
            out, status = Open3.capture2e(cmd)

            raise "Failed to run git command #{cmd}: #{out}" unless status.success?

            # Sometimes Encoding.default_external is somehow set to US-ASCII which breaks
            # commit messages with UTF-8 characters like emojis
            # We force output's encoding to be UTF-8 in this case
            # This is safe to do as UTF-8 is compatible with US-ASCII
            if Encoding.default_external == Encoding::US_ASCII
              out = out.force_encoding(Encoding::UTF_8)
            end
            out.strip! # There's always a "\n" at the end of the command output

            return nil if out.empty?

            out
          end
        end
      end
    end
  end
end
