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

# Version: 0.2

 require 'optparse' # OptionParser (Ruby built-in)
 require 'fileutils' # FileUtils (gem install fileutils)

$options = {} # This hash will hold all of the options parsed from the command-line by OptionParser.
$inserted_copyright = [] # List of all files where header inserted
$cleaned_copyright = [] # List of all files where header cleaned
$unknown_files = [] # List of files of unknown type
$existing_copyright = []# List of files with existing Copyright
$COPYRIGHT_HEADER_START = "COPYRIGHT HEADER START" # Identifier at the start of inserted header
$COPYRIGHT_HEADER_END = "COPYRIGHT HEADER END" # Identifier at the end of inserted header

class CopyrightHeaderTool

  # insert copyright header in all files of a directory
  def insert_all(dir)
    require 'find'
    Find.find(dir + '/') do |f|
      f.sub!(Dir.pwd + '/', '') # remove working dir path for readable output (= use relative paths)
      Find.prune if File.basename(f)[0] == ?. # Ignore hidden files and folders
      Find.prune if File.basename(f) == File.basename(__FILE__) # Exclude the Tool itself
      Find.prune if (f + '/' == "#{$options[:outputdir]}") # Ignore output dir when inserting, omit recursion
      if File.file?(f)
        insert_header(f) # Insert header
      end
    end
  end
  def clean_all(dir)
    require 'find'
    Find.find(dir + '/') do |f|
      f.sub!(Dir.pwd + '/', '') # remove working dir path for readable output (= use relative paths)
      Find.prune if File.basename(f)[0] == ?. # Ignore hidden files and folders
      Find.prune if File.basename(f) == File.basename(__FILE__) # Exclude the Tool itself
      if File.file?(f)
        clean_header(f) # Clean header
      end
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
  def insert_header(file)
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
        $inserted_copyright << file
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
    { :start => comm_start + " | # #{$COPYRIGHT_HEADER_START} #",
      :line => comm_line + "|  ",
      :end => comm_line + "| # #{$COPYRIGHT_HEADER_END} #" + comm_end,
    }
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

  # get position of header[:start], header[:end]
  def find_copyright_header(file, n = 10)
    header = {}
    fsize = File.readlines(file).size
    f = File.new(file, 'r')
    n = fsize if (fsize < n) # prevent from searching beyond EOF
    n.times do
      if (f.readline.include? $COPYRIGHT_HEADER_START)
        header[:start]=f.lineno  #Line Number of Header Start
        while !(f.readline.include? $COPYRIGHT_HEADER_END) : next end
        header[:end]=f.lineno
        break # Stop loop when header found
      end
    end
    header
  end

  def clean_header(file)
    header = find_copyright_header(file)
    if !header.empty? # only when header found
      f = File.new(file, 'r')
      file_content = ""
      (header[:start]-1).times do
        file_content << f.readline # read lines before header
      end
      f.readline while (f.lineno < header[:end]) # jump over every line till header_end
      line = f.readline
      file_content << line if !line.chomp.empty? # add first line after header if not empty
      file_content << f.readline while !f.eof? # read lines after header
      # puts file_content
      File.new(file, 'w').write(file_content)
      $cleaned_copyright << file
    end
  end
end

def write_inserted
  puts "Header inserted in following files:"
  $inserted_copyright.each do |f|
    puts "  " + f
  end
end
def write_cleaned
  puts "Header cleaned in following files:"
  $cleaned_copyright.each do |f|
    puts "  " + f
  end
end
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

class OptionParser
  def self.parse(args)
    options = {}
    optparse = OptionParser.new do |opts|
      # Set a banner, displayed at the top
      # of the help screen.
      opts.banner = "Usage: CopyrightHeaderTool.rb options [file]"
      
      # Define the options, and what they do
      #options[:verbose] = false
      #opts.on( '-v', '--verbose', 'Output more information' ) do
      #  options[:verbose] = true
      #end
      
      options[:noop] = false
      opts.on( '-n', '--noop', 'Output the parsed files to STDOUT, do not change the files' ) do
        options[:noop] = true
      end
      
      options[:outputdir] = 'copyrighted/'
      opts.on( '-o', '--outputdir DIR', 'Use DIR as output directory, default is "copyrighted/"
          (Use  -o "." for in-place inserting )' ) do |dir|
        options[:outputdir] = dir + '/'
      end
      
      options[:license] = 'License'
      opts.on( '-l', '--license FILE', 'Use FILE as Header, default is "License"' ) do|file|
        options[:license] = file
      end
      opts.on( '-c', '--clean-header FILE', 'Clean Header in FILE' ) do|file|
        options[:clean] = file
      end
      opts.on( '-A', '--all', 'Insert Header in all Files in current folder and subdirectories' ) do
        options[:all] = true
      end
      opts.on( '-C', '--clean-all', 'Clean Header in all Files in current folder and subdirectories' ) do
        options[:clean_all] = true
      end
      opts.on( '-f', '--file FILE', 'Insert Header in FILE' ) do|file|
        options[:file] = file
      end
      
      # This displays the help screen, all programs are
      # assumed to have this option.
      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        exit
      end
    end
    optparse.parse!(args)
    options
  end # parse()
end


# Main

$options = OptionParser.parse(ARGV)
CHT = CopyrightHeaderTool.new # New instance of CHT

# Clean Copyright if option set
CHT.clean_header($options[:clean]) if $options[:clean]
# Insert Copyright in specific file
CHT.insert_header($options[:file]) if $options[:file]
# Insert Copyright in all files
CHT.insert_all(Dir.pwd) if $options[:all]
# Clean Copyright in all files
CHT.clean_all(Dir.pwd) if $options[:clean_all]

write_inserted if !($inserted_copyright.empty?)
write_ignored_files if !($unknown_files.empty?)
write_existing_copyright() if !($existing_copyright.empty?)
write_cleaned if !($cleaned_copyright.empty?)
