#!/usr/bin/env ruby

# A totally ghetto method to sort out PRs.

require 'fileutils'
require 'tempfile'

@prs = []
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

get_prs
data = File.open(@temp_prs, "rb") {|f| f.read f.stat.size}
@prs = []

data.each_line do |line|
	next unless line =~ /metasploit-framework\/pull\/([0-9]+)/
	 pr = $1.to_i
	 @prs << pr unless @prs.include? pr
end

@prs.sort!

@prs.each do |pr|
	puts "https://github.com/rapid7/metasploit-framework/pull/#{pr}"
end
