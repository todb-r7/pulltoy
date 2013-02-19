#!/usr/bin/env ruby

# A totally ghetto method to sort out PRs.

require 'fileutils'
require 'tempfile'
require 'open-uri'
require 'nokogiri'
require 'time'

@prs = {}
@pr_numbers = []
@docs = {}
@temp_prs = Tempfile.new("pull-requests")

def get_prs
	File.unlink @temp_prs.path rescue nil
	1.upto(10) do |i|
		url = "https://github.com/rapid7/metasploit-framework/pulls?direction=desc&page=#{i}&sort=created&state=open"
		cmd = "curl -Lo- '#{url}' >> #{@temp_prs.path}"
		system(cmd)
		if i >=1
			puts "Breaking!"
			break
		end
	end
end

def parse(i)
	url = "https://github.com/rapid7/metasploit-framework/pull/#{i}"
	@docs[i] = Nokogiri::HTML(open(url))
end

def get_author(i)
	doc = @docs[i]
	doc.css('//p/a').each do |a|
		if a.to_s.include? "pull-header-username"
			return a.attributes["href"].value[1,0xffff]
		end
	end
end

def get_title(i)
	doc = @docs[i]
	doc.css('h2').first.children.to_s
end

def get_file_count(i)

end

def get_commit_count(i)

end

def get_date(i)
	doc = @docs[i]
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

@pr_numbers.each do |pr|
	parse(pr)
	author = get_author(pr)
	url = "https://github.com/rapid7/metasploit-framework/pull/#{pr}"
	title = get_title(pr)
	date = get_date(pr)
	puts [pr,author,url,title,date].inspect
end


