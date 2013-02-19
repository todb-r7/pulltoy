#!/usr/bin/env ruby

# A totally ghetto method to sort out PRs.

require 'fileutils'
require 'tempfile'
require 'open-uri'
require 'nokogiri'

@prs = {}
@pr_numbers = []
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

def get_author(i)
	url = "https://github.com/rapid7/metasploit-framework/pull/#{i}"
	doc = Nokogiri::HTML(open(url))
	doc.css('//p/a').each do |a|
		if a.to_s.include? "pull-header-username"
			return a.attributes["href"].value[1,0xffff]
		end
	end
end

def get_files(i)

end

def get_lines_of_change(i)

end

def get_date(i)

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
	author = get_author(pr)
	url = "https://github.com/rapid7/metasploit-framework/pull/#{pr}"
	puts [pr,author,url].inspect
end


