#!/usr/bin/ruby
# encoding: UTF-8

 # # # For cleaning up after deploying to PROD # # # # #
#                                                       #
  DESC = <<-DESCRIPTION
    
    1. Merge the release branch into the master branch
    2. Tag the last commit of the master branch
    3. Delete the release branch
    4. Merge the master branch into the develop branch
  DESCRIPTION
#                                                       #
 # # # # # # # # # # # # # # # # # # # # # # # # # # # #

def clean_up!
  show_usage unless ARGV.size == 2

  master  = "master"
  develop = "develop"
  release = ARGV[0]
  version = ARGV[1]

  verify release, version

  # 1. Merge the release branch into the master branch
  check_out release
  pull if branch_is_remote release
  check_out master
  pull
  merge release

  # 2. Tag the last commit of the master branch
  tag version

  # 3. Delete the release branch
  delete release

  # 4. Merge the master branch into the develop branch
  check_out develop
  pull
  merge master


  puts "\nDone!"
end


# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # #

def verify(branch, tag)
  unless branch.include? "release" or branch.include? "hotfix"
    puts "No! This is not a release branch. >:["
    exit
  end
  if (run "git tag").split("\n").inject(false) {|ans, t| ans or t === tag}
    puts "Tag #{tag} already exists. Run 'git tag' to see which tags are already taken."
    exit
  end
end

def check_out(branch)
  puts
  run "git checkout #{branch}"
end

def pull
  branch = current_branch.chomp
  puts ">> Pulling changes from '#{branch}'"
  run "git pull origin #{branch}"
end

def merge(branch)
  puts "\n>> Merging '#{branch}' into '#{current_branch.chomp}'"
  run "git merge #{branch}"
  run "git push origin #{current_branch}"
end

def tag(version)
  puts "\n>> Tagging the last commit of '#{current_branch.chomp}' with '#{version}'"
  run "git tag -a #{version} -m 'Release version #{version}'"
  run "git push origin #{version}"
end

def delete(branch)
  puts "\n>> Deleting '#{branch}'"
  run "git branch -D #{branch}"
  run "git push origin --delete #{branch}" if branch_is_remote branch
end

def branch_is_remote(branch)
  (run "git branch -r").split("\n").inject(false) {|ans, b| ans or b.include? branch}
end

def current_branch
  run "git rev-parse --abbrev-ref HEAD"
end

def run(command)
  res = %x[ #{command} ]
  unless $?.exitstatus === 0
    if command == "git merge master"
      puts "Failed merging master into develop branch (probably due to conflicts)."
      puts "Resolve conflicts and commit manually to complete clean up."
    else
      puts "Operation failed while doing: '#{command}'. Do the rest of the clean up manually."
    end
    exit
  end
  res
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
