RSpec.describe "gem release process" do
  context "datadog-ci.gemspec" do
    context "files" do
      subject(:files) { Gem::Specification.load("datadog-ci.gemspec").files }

      # It's easy to forget to ship new files, especially when a new paradigm is
      # introduced (e.g. introducing native files requires the inclusion `ext/`)
      it "includes all important files" do
        single_files_excluded = /
          ^
          (
           |\.env
           |\.gitignore
           |\.rspec
           |\.rubocop.yml
           |\.standard.yml
           |\.standard_todo.yml
           |\.simplecov
           |\.yardopts
           |Appraisals
           |CODE_OF_CONDUCT.md
           |CONTRIBUTING.md
           |CODEOWNERS
           |Gemfile
           |Gemfile-.*
           |Rakefile
           |Steepfile
           |datadog-ci\.gemspec
           |docker-compose\.yml
          )
          $
        /x

        directories_excluded = %r{
          ^(
            spec
            |sig
            |docs
            |\.circleci
            |\.github
            |\.vscode
            | bin
            |gemfiles
            |integration
            |tasks
            |yard
            |vendor/rbs
          )/
        }x

        expect(files)
          .to match_array(
            `git ls-files -z`
              .split("\x0")
              .reject { |f| f.match(directories_excluded) }
              .reject { |f| f.match(single_files_excluded) }
          )
      end
    end
  end
end
