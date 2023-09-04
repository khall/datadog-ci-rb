# frozen_string_literal: true

require_relative "../environment"
require_relative "../git"

module Datadog
  module CI
    module Ext
      module Environment
        # Provider is a specific CI provider like Azure Pipelines, Github Actions, Gitlab CI, etc
        # Extractor is responsible for detecting where pipeline is being executed based on environment vars
        # and return the specific extractor that is able to return environment- and git-specific tags
        class Extractor
          require_relative "providers/default"
          require_relative "providers/appveyor"
          require_relative "providers/azure"
          require_relative "providers/bitbucket"
          require_relative "providers/bitrise"
          require_relative "providers/buddy"
          require_relative "providers/buildkite"
          require_relative "providers/circleci"
          require_relative "providers/codefresh"
          require_relative "providers/github_actions"
          require_relative "providers/gitlab"
          require_relative "providers/jenkins"
          require_relative "providers/teamcity"
          require_relative "providers/travis"

          PROVIDERS = [
            ["APPVEYOR", Providers::Appveyor],
            ["TF_BUILD", Providers::Azure],
            ["BITBUCKET_COMMIT", Providers::Bitbucket],
            ["BITRISE_BUILD_SLUG", Providers::Bitrise],
            ["BUDDY", Providers::Buddy],
            ["BUILDKITE", Providers::Buildkite],
            ["CIRCLECI", Providers::Circleci],
            ["CF_BUILD_ID", Providers::Codefresh],
            ["GITHUB_SHA", Providers::GithubActions],
            ["GITLAB_CI", Providers::Gitlab],
            ["JENKINS_URL", Providers::Jenkins],
            ["TEAMCITY_VERSION", Providers::Teamcity],
            ["TRAVIS", Providers::Travis]
          ]

          def self.for_environment(env)
            _, extractor_klass = PROVIDERS.find { |provider_env_var, _| env.key?(provider_env_var) }
            extractor_klass = Providers::Default if extractor_klass.nil?

            extractor_klass.new(env)
          end

          def initialize(env)
            @env = env
          end

          def tags
            {
              Environment::TAG_JOB_NAME => job_name,
              Environment::TAG_JOB_URL => job_url,
              Environment::TAG_PIPELINE_ID => pipeline_id,
              Environment::TAG_PIPELINE_NAME => pipeline_name,
              Environment::TAG_PIPELINE_NUMBER => pipeline_number,
              Environment::TAG_PIPELINE_URL => pipeline_url,
              Environment::TAG_PROVIDER_NAME => provider_name,
              Environment::TAG_STAGE_NAME => stage_name,
              Environment::TAG_WORKSPACE_PATH => workspace_path,
              Environment::TAG_NODE_LABELS => node_labels,
              Environment::TAG_NODE_NAME => node_name,
              Environment::TAG_CI_ENV_VARS => ci_env_vars,

              Git::TAG_BRANCH => git_branch,
              Git::TAG_REPOSITORY_URL => git_repository_url,
              Git::TAG_TAG => git_tag,
              Git::TAG_COMMIT_AUTHOR_DATE => git_commit_author_date,
              Git::TAG_COMMIT_AUTHOR_EMAIL => git_commit_author_email,
              Git::TAG_COMMIT_AUTHOR_NAME => git_commit_author_name,
              Git::TAG_COMMIT_COMMITTER_DATE => git_commit_committer_date,
              Git::TAG_COMMIT_COMMITTER_EMAIL => git_commit_committer_email,
              Git::TAG_COMMIT_COMMITTER_NAME => git_commit_committer_name,
              Git::TAG_COMMIT_MESSAGE => git_commit_message,
              Git::TAG_COMMIT_SHA => git_commit_sha
            }.reject do |_, v|
              # setting type of v here to untyped because steep does not
              # understand `v.nil? || something`

              # @type var v: untyped
              v.nil? || v.strip.empty?
            end
          end

          private

          attr_reader :env

          def job_name
          end

          def job_url
          end

          def pipeline_id
          end

          def pipeline_name
          end

          def pipeline_number
          end

          def pipeline_url
          end

          def provider_name
          end

          def stage_name
          end

          def workspace_path
          end

          def node_labels
          end

          def node_name
          end

          def ci_env_vars
          end

          def git_branch
          end

          def git_repository_url
          end

          def git_tag
          end

          def git_branch_or_tag
          end

          def git_commit_author_date
          end

          def git_commit_author_email
          end

          def git_commit_author_name
          end

          def git_commit_committer_date
          end

          def git_commit_committer_email
          end

          def git_commit_committer_name
          end

          def git_commit_message
          end

          def git_commit_sha
          end

          def branch_or_tag(branch_or_tag_string)
            @branch = @tag = nil
            if branch_or_tag_string && branch_or_tag_string.include?("tags/")
              @tag = branch_or_tag_string
            else
              @branch = branch_or_tag_string
            end

            [@branch, @tag]
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
        end
      end
    end
  end
end
