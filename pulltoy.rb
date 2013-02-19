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
		if i >=5
			puts "Breaking!"
			break
		end
	end
end

def parse(i)
	url = "https://github.com/rapid7/metasploit-framework/pull/#{i}"
	url_files = url << "/files"
	@pr_pages[i] = Nokogiri::HTML(open(url))
	@pr_files[i] = Nokogiri::HTML(open(url_files))
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
	add_del = changes.scan(/\d+/).map {|i| i.to_i}
	add_del.inject {|sum, i| sum += i}
end

def get_date(i)
	doc = @pr_pages[i]
	date = Time.parse(doc.css('time').first.attributes['datetime'].value)
	date.strftime("%Y-%m-%d")
end

get_prs
data = File.open(@temp_prs, "rb") {|f| f.read f.stat.size}
@pr_numbers = []

data.each_line do |line|
	next unless line =~ /metasploit-framework\/pull\/([0-9]+)/
	 pr = $1.to_i
	 @pr_numbers << pr unless @pr_numbers.include? pr
end

@pr_numbers.sort!

csv_title = %w{Pull Changes Author Date Title URL}.to_csv
puts csv_title
@pr_numbers.each do |pr|
	parse(pr)
	author = get_author(pr)
	url = "https://github.com/rapid7/metasploit-framework/pull/#{pr}"
	title = get_title(pr)
	date = get_date(pr)
	lines = get_line_count(pr)
	this_pr = [pr,lines,author,date,title,url]
	puts this_pr.to_csv
	$stdout.flush
end
