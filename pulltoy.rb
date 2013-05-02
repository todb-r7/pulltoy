#!/usr/bin/env ruby

# A totally ghetto method to sort out PRs. Works for now, totally
# dependant on GitHub's HTML which could change at any moment.
# This is a stopgap until I have something using Github's API proper.
# Doesn't take arguments, just run:
#
# ruby pulltoy.rb | tee out.csv
#
# To get a current prioritizable list of what should be dealt with,
# PR-wise
#

require 'fileutils'
require 'tempfile'
require 'open-uri'
require 'nokogiri'
require 'time'
require 'csv'

@prs = {}
@pr_numbers = []
@pr_pages = {}
@pr_files = {}
@temp_prs = Tempfile.new("pull-requests")

def get_prs
	File.unlink @temp_prs.path rescue nil
	1.upto(10) do |i|
		url = "https://github.com/rapid7/metasploit-framework/pulls?direction=desc&page=#{i}&sort=created&state=open"
		cmd = "curl -Lo- '#{url}' >> #{@temp_prs.path}"
		system(cmd)
		break if i >=5
	end
end

def parse(i)
	url = "https://github.com/rapid7/metasploit-framework/pull/#{i}"
	url_files = url << "/files"
	@pr_pages[i] = Nokogiri::HTML(open(url))
	sleep rand(4)+1
	@pr_files[i] = Nokogiri::HTML(open(url_files))
	sleep rand(4)+1
end

def get_author(i)
	doc = @pr_pages[i]
	doc.css('//p/a').each do |a|
		if a.to_s.include? "pull-header-username"
			return a.attributes["href"].value[1,0xffff]
		end
	end
end

def get_title(i)
	doc = @pr_pages[i]
	doc.css('h2').first.children.to_s
end

def get_line_count(i)
	doc = @pr_files[i]
	changes = doc.css('span[@class = "diffstat tooltipped downwards"]').first['title']
	add_del = changes.gsub(/,/,"").scan(/\d+/).map {|i| i.to_i}
	add_del.inject {|sum, i| sum += i}
end

def get_file_count(i)
	doc = @pr_files[i]
	files = doc.css('span[@id = "files_tab_counter"]').inner_html.strip
end

def get_date(i)
	doc = @pr_pages[i]
	date = Time.parse(doc.css('time').first.attributes['datetime'].value)
	date.strftime("%Y-%m-%d")
end

# For some reason, these PRs give trouble
# 1217: Refactor of Java Meterpreter. It's really long, but MIRV is
# longer (PR 1182) and doesn't hang forever.
def skip_pr(i)
	[1217].include? i
end

def build_csv_record(pr)
	parse(pr)
	author = get_author(pr)
	url = "https://github.com/rapid7/metasploit-framework/pull/#{pr}"
	title = get_title(pr)
	date = get_date(pr)
	files = get_file_count(pr)
	lines = get_line_count(pr)
	this_pr = [pr,files,lines,author,date,title,url]
	this_pr.to_csv
end

def build_merge_command(pr)
	parse(pr)
	doc = @pr_files[pr]
	pull_desc = doc.css('div[@class="pull-description"]/p').text
	source = pull_desc.split(/\s+/).last
	if source.include? ":"
		repo,branch = source.split(":")
	else
		repo,branch = ["upstream",source]
	end
	cmd = []
	if repo == "upstream"
	cmd << "git checkout -b #{branch} --track upstream/#{branch}"
	cmd << "git checkout upstream-master"
	cmd << "git merge --no-commit --no-ff #{branch}"
	else
	cmd << "git remote add -f #{repo} git://github.com/#{repo}/metasploit-framework.git"
	cmd << "git fetch #{repo}"
	cmd << "git checkout -b #{repo}-#{branch} --track #{repo}/#{branch}"
	cmd << "git checkout upstream-master"
	cmd << "git merge --no-commit --no-ff #{repo}-#{branch}"
	end
	cmd << "git reset --hard HEAD"
	cmd << "echo 'COMPLETED PR ##{pr} for #{repo}/#{branch}'"
	cmd << "sleep 3"
	cmd.join(";")
end

get_prs
data = File.open(@temp_prs, "rb") {|f| f.read f.stat.size}
@pr_numbers = []
data.each_line do |line|
	next unless line =~ /metasploit-framework\/pull\/([0-9]+)/
	 pr = $1.to_i
	 @pr_numbers << pr unless @pr_numbers.include? pr
end

def build_csv
	csv_title = %w{Pull Files Lines Author Date Title URL}.to_csv
	puts csv_title
	@pr_numbers.each do |pr|
		next if skip_pr(pr)
		$stdout.puts build_csv_record(pr)
		$stdout.flush
	end
end

def build_merge_test_script
	@pr_numbers.each do |pr|
		next if skip_pr(pr)
		$stdout.puts build_merge_command(pr)
		$stdout.flush
	end
end

# Okay, go!
# build_csv()
build_merge_test_script
