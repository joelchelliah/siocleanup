#!/usr/bin/ruby
# encoding: UTF-8

 # # # For cleaning up after deploying to PROD # # # # #
#                                                       #
  DESC = <<-DESCRIPTION

    1. Check out the release branch
    2. If [version/tag] is not specified, get version from pom.xml in current directory.
    3. Merge the release branch into the master branch
    4. Tag the last commit of the master branch with [version/tag]
    5. Delete the release branch
    6. Merge the master branch into the develop branch
  DESCRIPTION
#                                                       #
 # # # # # # # # # # # # # # # # # # # # # # # # # # # #

def clean_up!
  show_usage unless ARGV.size == 1 or ARGV.size == 2
  version_not_specified = ARGV.size == 1

  master  = "master"
  develop = "develop"
  release = ARGV[0]
  version = ARGV[1]

  verify :release_branch => release

  git_check_out release

  version = get_version_from_pom if version_not_specified

  verify :version_or_tag => version

  merge release, :into => master
  
  tag version

  delete release

  merge master, :into => develop

  finish! "👍"
end


# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #


def get_version_from_pom()
  path = "#{Dir.pwd}/pom.xml"
  puts "\n >> Getting [version/tag] from: " << path.pink
  unless File.exists? path
    error_message "File does not exist", path
    finish!
  end
  File.open(path) do |f|
  f.each_line do |line|
    m = line.match(/<version>(.*)<\/version>/)
    return m[1] if m
  end
end
  error_message "Could not find [version/tag] from", path
  finish!
end

def verify(hsh = {})
  if hsh[:release_branch]
    branch = hsh[:release_branch]
    unless (branch.include? "release" or branch.include? "hotfix")
      error_message "No! This is not a release branch", branch
      finish!
    end
  elsif hsh[:version_or_tag] and (run "git tag").split("\n").inject(false) {|ans, t| ans or t === tag}
    error_message "This tag already exists", tag
    info_message "Run 'git tag' to see which tags are already taken."
    finish!
  else
    error_message "Invalid verify command", hsh.to_s
  end
end

def merge(branch, hsh = {})
  puts "\n >> Merging " << branch.pink << " into " << hsh[:into].pink
  git_check_out branch
  git_pull if is_remote branch
  git_check_out hsh[:into]
  git_pull
  git_merge_and_push branch
end

def tag(version)
  puts "\n >> Tagging the last commit of " << current_branch.chomp.pink << " with " << version.green
  run "git tag -a #{version} -m 'Release version #{version}'"
  run "git push -q origin #{version}"
end

def delete(branch)
  puts "\n >> Deleting " << branch.pink
  run "git branch -D #{branch} -q"
  run "git push origin --delete #{branch} -q" if is_remote branch
end

def git_check_out(branch)
  unless current_branch.include? branch
    info_message "Checking out", branch
    run "git checkout #{branch} -q"
  end
end

def git_pull
  branch = current_branch.chomp
  info_message "Pulling changes from", branch
  run "git pull origin #{branch} -q"
end

def git_merge_and_push(branch)
  info_message "Merging", "#{branch} -> #{current_branch.chomp}"
  run "git merge #{branch} -q"
  run "git push -q origin #{current_branch}"
end

def is_remote(branch)
  (run "git branch -r").split("\n").inject(false) {|ans, b| ans or b.include? branch}
end

def current_branch
  run "git rev-parse --abbrev-ref HEAD"
end

def run(command)
  res = %x[ #{command} ]
  unless $?.exitstatus === 0
    if command.include? "git merge master"
      error_message "Failed merging master into develop branch", "probably due to conflicts"
      info_message "Resolve conflicts and commit to develop to complete clean-up."
    else
      error_message "Operation failed while doing", command
      info_message "Do the rest of the clean up manually."
    end
    finish!
  end
  res
end

def info_message(text, reason = nil)
  if reason
    puts "    > #{text}: [ ".yellow << reason.green << " ]".yellow
  else
    puts "    > #{text}"
  end
end

def error_message(text, reason)
  puts "   !> #{text}: [ ".red << "#{reason}" << " ]".red
end

def finish!(status="👎")
  puts "\n >> Done " << status
  exit
end

def show_usage
  puts <<-END

   #{"Please provide 1-2 parameters. Recieved #{ARGV.size} parameter(s)".red}.

   #{"Usage:".yellow}
    siocleanup [release branch] (version/tag)

    #{"e.g:".green} siocleanup release-6.4.2
    #{"e.g:".green} siocleanup release-6.4.2 6.4.2

   #{"This script will:".yellow} #{DESC}
   END
   exit
end

# # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Colorization

class String
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red
    colorize(31)
  end

  def green
    colorize(32)
  end

  def yellow
    colorize(33)
  end

  def pink
    colorize(35)
  end
end

# # # # # # # # # # # # # # # # # # # # # # # # # # # #

clean_up!
