# frozen_string_literal: true
class Changeset::Files
  include Enumerable

  attr_reader :github, :files

  def initialize(files=nil, github=true)
    @files = files || []
    @github = github

    unless github
      @files = gitlab_transform_file(@files)
    end

  end

  def each(&block)
    @files.each(&block)
  end

  def gitlab_transform_file(files)
    new_files = []
    files.each do |file|
      status = 'modified'
      status = 'renamed' if file['renamed_file']
      status = 'added' if file['new_file']
      status = 'deleted' if file['deleted_file']

      additions = file[:diff]
      new_files << OpenStruct.new({
        status: status,
        previous_filename: file['old_path'],
        filename: file['new_path'],
        additions: file['diff'].scan(/^\+[^+].*$/).count,
        deletions: file['diff'].scan(/^-[^-].*$/).count,
        patch: file['diff']
      })
    end
    @files = new_files
  end

  def ==(rhs)
    self.files.inspect == rhs.files.inspect
  end


end
