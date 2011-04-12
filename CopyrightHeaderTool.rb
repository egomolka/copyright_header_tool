#! /usr/bin/env ruby

# CopyrightHeaderTool - Insert a Copyright Header into many files with different syntax
# Copyright (C) 2011 Puzzle ITC GmbH - www.puzzle.ch
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Version: 0.1

 require 'optparse' # OptionParser (Ruby built-in)
 require 'fileutils' # FileUtils (gem install fileutils)

$options = {} # This hash will hold all of the options parsed from the command-line by OptionParser.
$unknown_files = [] # List of files of unknown type
$existing_copyright = []# List of files with existing Copyright
$COPYRIGHT_HEADER_START = "COPYRIGHT HEADER START"
$COPYRIGHT_HEADER_END = "COPYRIGHT HEADER END"

class CopyrightHeaderTool

	# insert copyright header in all files of a directory
	def recursive_insert(dir)
		require 'find'
		Find.find(dir + '/') do |f|
			type = case
					when File.file?(f) then "  F"
					when File.directory?(f) then "D"
					else "?"
				end
				f.sub!(Dir.pwd + '/', '') # remove working dir path for readable output (= use relative paths)
				Find.prune if File.basename(f)[0] == ?. # Ignore hidden files and folders
				Find.prune if f + '/' == "#{$options[:outputdir]}" # Ignore output dir, omit recursion
			puts "#{type}: #{f}"
			insert_license(f) if File.file?(f)
		end
	end
	
	# Generate commented copyright header
	def copyright_header(type)
		syntax = comment_syntax_type(type)
		comment = "#{syntax[:start]} \n"
		File.open($options[:license], 'r').each {|l| comment << "#{syntax[:line]} #{l}"}
		comment << "#{syntax[:end]} \n\n"
	end
	
	# Insert license in file
	def insert_license(file)
		type = filetype(File.extname(file))
		if type != 'unknown'
			f = File.new(file, 'r')
			file_content = f.read
			header = copyright_header(type)
			
			if copyright_check(file)
				
				$existing_copyright << file
			end
			file_content = header + file_content
			
			if $options[:noop]
				puts file_content
			else
				dir = "#{$options[:outputdir]}/#{File.dirname(f.path)}"
				FileUtils.mkpath dir if !File.directory?(dir)
				outputpath = "./" + $options[:outputdir] + file
				File.new(outputpath, 'w').write(file_content)
			end
		else
			$unknown_files << file
		end
	end
	
	# get filetype from extension
	def filetype(ext) 
		if (['.html', '.htm', '.xhtml'].include? ext)
			type = 'html'
		elsif (['.rb'].include? ext)
			type = 'ruby'
		elsif ('.erb' == ext)
			type = 'erb'
		elsif ('.js' == ext)
			type = 'javascript'
		elsif ('.css' == ext)
			type = 'css'
		elsif ('.yml' == ext)
			type = 'yaml'
		else
			type = 'unknown'
		end
	end
	
	# get hash with comment syntax by filetype
	def comment_syntax_type(type)
		case type
			when 'html'
				syntax = comment_syntax('<!-- ', '', ' -->')
			when 'ruby'
				syntax = comment_syntax('# ', '# ', '')
			when 'erb'
				syntax = comment_syntax('<% # ', '# ', ' %>')
			when 'css'
				syntax = comment_syntax('/* ', ' * ', ' */ ')
			when 'javascript'
				syntax = comment_syntax('// ', '// ', '')
			when 'yaml'
				syntax = comment_syntax('# ', '# ', '')
			else
				syntax = comment_syntax()
		end
	end

	# get hash with comment syntax with specified syntax
	def comment_syntax(comm_start = '#', comm_line = '#', comm_end = '')
		c_syntax = Hash.new
		c_syntax[:start] = comm_start + "| # #{$COPYRIGHT_HEADER_START} #"
		c_syntax[:line] = comm_line + "|  "
		c_syntax[:end] = comm_line + "| # #{$COPYRIGHT_HEADER_START} #" + comm_end
		c_syntax
	end
	
	# Check file for existing Copyright
	def copyright_check(file, n = 10)
		f = File.new(file, 'r')
		has_copyright = false
		fsize = File.readlines(file).size
		n = fsize if (fsize < n)
		n.times do
			has_copyright ||= (/[Cc]opyright/ =~ f.readline)
		end
		has_copyright
	end
end

options = {}
optparse = OptionParser.new do |opts|
	# Set a banner, displayed at the top
	# of the help screen.
	opts.banner = "Usage: CopyrightHeaderTool.rb [options] [file]"
	
	# Define the options, and what they do
	options[:verbose] = false
	opts.on( '-v', '--verbose', 'Output more information' ) do
		options[:verbose] = true
	end
	
	options[:noop] = false
	opts.on( '-n', '--noop', 'Output the parsed files to STDOUT, do not change the files' ) do
		options[:noop] = true
	end
	
	options[:outputdir] = 'copyrighted/'
	opts.on( '-o', '--outputdir DIR', 'Use DIR as output directory, default is "copyrighted/"' ) do|dir|
		options[:outputdir] = dir + '/'
	end
	
	options[:license] = 'License'
	opts.on( '-l', '--license FILE', 'Use FILE as Header, default is "License"' ) do|file|
		options[:license] = file
	end
	
	# This displays the help screen, all programs are
	# assumed to have this option.
	opts.on( '-h', '--help', 'Display this screen' ) do
		puts opts
		exit
	end
end

optparse.parse!
$options = options # make options global

def write_existing_copyright
	puts "\nWARNING: Existing Copyright found in following files:"
	$existing_copyright.each do |f|
		puts "  " + f
	end
end

def write_ignored_files
	puts "\nIgnored files (unknown filetype):"
	$unknown_files.each do |f|
		puts "  " + f
	end
end

if (!ARGV.empty?)
	CopyrightHeaderTool.new.insert_license("#{ARGV[0]}")
else
	CopyrightHeaderTool.new.recursive_insert(Dir.pwd)
end
write_ignored_files if !($unknown_files.empty?)
write_existing_copyright() if !($existing_copyright.empty?)
