# frozen_string_literal: true

require "open3"
require "json"

require_relative "git"
require_relative "environment/extractor"

module Datadog
  module CI
    module Ext
      # Defines constants for CI tags
      module Environment
        TAG_JOB_NAME = "ci.job.name"
        TAG_JOB_URL = "ci.job.url"
        TAG_PIPELINE_ID = "ci.pipeline.id"
        TAG_PIPELINE_NAME = "ci.pipeline.name"
        TAG_PIPELINE_NUMBER = "ci.pipeline.number"
        TAG_PIPELINE_URL = "ci.pipeline.url"
        TAG_PROVIDER_NAME = "ci.provider.name"
        TAG_STAGE_NAME = "ci.stage.name"
        TAG_WORKSPACE_PATH = "ci.workspace_path"
        TAG_NODE_LABELS = "ci.node.labels"
        TAG_NODE_NAME = "ci.node.name"
        TAG_CI_ENV_VARS = "_dd.ci.env_vars"

        module_function

        def tags(env)
          # Extract metadata from CI provider environment variables
          tags = Environment::Extractor.for_environment(env).tags

          # If user defined metadata is defined, overwrite
          tags.merge!(extract_user_defined_git(env))

          # Normalize Git references
          if !tags[Git::TAG_BRANCH].nil? && tags[Git::TAG_BRANCH].include?("tags/")
            tags[Git::TAG_TAG] = tags[Git::TAG_BRANCH]
            tags.delete(Git::TAG_BRANCH)
          end
          tags[Git::TAG_TAG] = normalize_ref(tags[Git::TAG_TAG])
          tags[Git::TAG_BRANCH] = normalize_ref(tags[Git::TAG_BRANCH])
          tags[Git::TAG_REPOSITORY_URL] = filter_sensitive_info(
            tags[Git::TAG_REPOSITORY_URL]
          )

          # Expand ~
          workspace_path = tags[TAG_WORKSPACE_PATH]
          if !workspace_path.nil? && (workspace_path == "~" || workspace_path.start_with?("~/"))
            tags[TAG_WORKSPACE_PATH] = File.expand_path(workspace_path)
          end

          # Fill out tags from local git as fallback
          extract_local_git.each do |key, value|
            tags[key] ||= value
          end

          tags.reject { |_, v| v.nil? }
        end

        def normalize_ref(name)
          refs = %r{^refs/(heads/)?}
          origin = %r{^origin/}
          tags = %r{^tags/}
          name.gsub(refs, "").gsub(origin, "").gsub(tags, "") unless name.nil?
        end

        def filter_sensitive_info(url)
          url.gsub(%r{(https?://)[^/]*@}, '\1') unless url.nil?
        end

        # CI providers
        def extract_user_defined_git(env)
          {
            Git::TAG_REPOSITORY_URL => env[Git::ENV_REPOSITORY_URL],
            Git::TAG_COMMIT_SHA => env[Git::ENV_COMMIT_SHA],
            Git::TAG_BRANCH => env[Git::ENV_BRANCH],
            Git::TAG_TAG => env[Git::ENV_TAG],
            Git::TAG_COMMIT_MESSAGE => env[Git::ENV_COMMIT_MESSAGE],
            Git::TAG_COMMIT_AUTHOR_NAME => env[Git::ENV_COMMIT_AUTHOR_NAME],
            Git::TAG_COMMIT_AUTHOR_EMAIL => env[Git::ENV_COMMIT_AUTHOR_EMAIL],
            Git::TAG_COMMIT_AUTHOR_DATE => env[Git::ENV_COMMIT_AUTHOR_DATE],
            Git::TAG_COMMIT_COMMITTER_NAME => env[Git::ENV_COMMIT_COMMITTER_NAME],
            Git::TAG_COMMIT_COMMITTER_EMAIL => env[Git::ENV_COMMIT_COMMITTER_EMAIL],
            Git::TAG_COMMIT_COMMITTER_DATE => env[Git::ENV_COMMIT_COMMITTER_DATE]
          }.reject { |_, v| v.nil? || v.strip.empty? }
        end

        def git_commit_users
          # Get committer and author information in one command.
          output = exec_git_command("git show -s --format='%an\t%ae\t%at\t%cn\t%ce\t%ct'")
          return unless output

          fields = output.split("\t").each(&:strip!)

          {
            author_name: fields[0],
            author_email: fields[1],
            # Because we can't get a reliable UTC time from all recent versions of git
            # We have to rely on converting the date to UTC ourselves.
            author_date: Time.at(fields[2].to_i).utc.to_datetime.iso8601,
            committer_name: fields[3],
            committer_email: fields[4],
            # Because we can't get a reliable UTC time from all recent versions of git
            # We have to rely on converting the date to UTC ourselves.
            committer_date: Time.at(fields[5].to_i).utc.to_datetime.iso8601
          }
        rescue => e
          Datadog.logger.debug(
            "Unable to read git commit users: #{e.class.name} #{e.message} at #{Array(e.backtrace).first}"
          )
          nil
        end

        def git_repository_url
          exec_git_command("git ls-remote --get-url")
        rescue => e
          Datadog.logger.debug(
            "Unable to read git repository url: #{e.class.name} #{e.message} at #{Array(e.backtrace).first}"
          )
          nil
        end

        def git_commit_message
          exec_git_command("git show -s --format=%s")
        rescue => e
          Datadog.logger.debug(
            "Unable to read git commit message: #{e.class.name} #{e.message} at #{Array(e.backtrace).first}"
          )
          nil
        end

        def git_branch
          exec_git_command("git rev-parse --abbrev-ref HEAD")
        rescue => e
          Datadog.logger.debug(
            "Unable to read git branch: #{e.class.name} #{e.message} at #{Array(e.backtrace).first}"
          )
          nil
        end

        def git_commit_sha
          exec_git_command("git rev-parse HEAD")
        rescue => e
          Datadog.logger.debug(
            "Unable to read git commit SHA: #{e.class.name} #{e.message} at #{Array(e.backtrace).first}"
          )
          nil
        end

        def git_tag
          exec_git_command("git tag --points-at HEAD")
        rescue => e
          Datadog.logger.debug(
            "Unable to read git tag: #{e.class.name} #{e.message} at #{Array(e.backtrace).first}"
          )
          nil
        end

        def git_base_directory
          exec_git_command("git rev-parse --show-toplevel")
        rescue => e
          Datadog.logger.debug(
            "Unable to read git base directory: #{e.class.name} #{e.message} at #{Array(e.backtrace).first}"
          )
          nil
        end

        def exec_git_command(cmd)
          out, status = Open3.capture2e(cmd)

          raise "Failed to run git command #{cmd}: #{out}" unless status.success?

          out.strip! # There's always a "\n" at the end of the command output

          return nil if out.empty?

          out
        end

        def extract_local_git
          env = {
            TAG_WORKSPACE_PATH => git_base_directory,
            Git::TAG_REPOSITORY_URL => git_repository_url,
            Git::TAG_COMMIT_SHA => git_commit_sha,
            Git::TAG_BRANCH => git_branch,
            Git::TAG_TAG => git_tag,
            Git::TAG_COMMIT_MESSAGE => git_commit_message
          }

          if (commit_users = git_commit_users)
            env.merge!(
              Git::TAG_COMMIT_AUTHOR_NAME => commit_users[:author_name],
              Git::TAG_COMMIT_AUTHOR_EMAIL => commit_users[:author_email],
              Git::TAG_COMMIT_AUTHOR_DATE => commit_users[:author_date],
              Git::TAG_COMMIT_COMMITTER_NAME => commit_users[:committer_name],
              Git::TAG_COMMIT_COMMITTER_EMAIL => commit_users[:committer_email],
              Git::TAG_COMMIT_COMMITTER_DATE => commit_users[:committer_date]
            )
          end

          env
        end

        def branch_or_tag(branch_or_tag)
          branch = tag = nil
          if branch_or_tag && branch_or_tag.include?("tags/")
            tag = branch_or_tag
          else
            branch = branch_or_tag
          end

          [branch, tag]
        end
      end
    end
  end
end
