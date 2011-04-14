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

# Version: 0.5


class CopyrightHeaderTool

 require 'optparse' # OptionParser (Ruby built-in)
 require 'fileutils' # FileUtils (gem install fileutils)
 
  attr_accessor :options, :inserted_copyright, :cleaned_copyright, :unknown_files, :existing_copyright
  
  @@COPYRIGHT_HEADER_START = "COPYRIGHT HEADER START" # Identifier at the start of inserted header
  @@COPYRIGHT_HEADER_END = "COPYRIGHT HEADER END" # Identifier at the end of inserted header
  @@head_patterns = { # when head patterns are found in the first lines, the copyright header is inserted after it 
    :general => ['#!'], # general file head identifiers, used for all filetypes
    :html => ['<!DOCTYPE', '<html', ] # filetype specific file head identifiers
  }
  @@extension_types = { # Hash of filetypes with corresponding extensions
    :ruby => ['.rb'],
    :html => ['.html', '.htm', '.xhtml'],
    :erb => ['.erb'],
    :javacript => ['.js'],
    :css => ['.css'],
    :yaml => ['.yml'],
  }
  @@syntax_types = { # Hash of filetypes and their comment syntax
    :ruby => ['# ', '# ', ''],
    :html => ['<!-- ', '', ' -->'],
    :erb => ['<% # ', '# ', ' %>'],
    :javacript => ['// ', '// ', ''],
    :css => ['/* ', ' * ', ' */ '],
    :yaml => ['# ', '# ', ''],
    :unknown => []
  }
  def initialize
    @options = {} # This hash will hold all of the options parsed from the command-line by OptionParser.
    @inserted_copyright = [] # List of all files where header inserted
    @cleaned_copyright = [] # List of all files where header cleaned
    @unknown_files = [] # List of files of unknown type
    @existing_copyright = []# List of files with existing Copyright
  end

  # insert copyright header in all files of a directory
  def insert_all(dir)
    require 'find'
    Find.find(dir + '/') do |f|
      f.sub!(Dir.pwd + '/', '') # remove working dir path for readable output (= use relative paths)
      Find.prune if File.basename(f)[0] == ?. # Ignore hidden files and folders
      Find.prune if File.basename(f) == File.basename(__FILE__) # Exclude the Tool itself
      Find.prune if (f + '/' == "#{@options[:outputdir]}") # Ignore output dir when inserting, omit recursion
      insert_header(f) if File.file?(f) # Insert header
    end
  end

  # clean copyright header in all files of a directory
  def clean_all(dir)
    require 'find'
    Find.find(dir + '/') do |f|
      f.sub!(Dir.pwd + '/', '') # remove working dir path for readable output (= use relative paths)
      Find.prune if File.basename(f)[0] == ?. # Ignore hidden files and folders
      Find.prune if File.basename(f) == File.basename(__FILE__) # Exclude the Tool itself
      clean_header(f) if File.file?(f) # Clean header
    end
  end

  # Generate commented copyright header (string)
  def copyright_header(type)
    syntax = comment_syntax_type(type)
    comment = "#{syntax[:start]} \n"
    File.open(@options[:license], 'r').each {|l| comment << "#{syntax[:line]} #{l}"} # Add each line commented
    comment << "#{syntax[:end]} \n\n"
  end

  # Insert license in file
  def insert_header(file)
    type = filetype(file)
    if type != :unknown
      header = copyright_header(type) # generate commented copyright header
      @existing_copyright << file if copyright_check(file) # add file to list if existing copyright found
      f = File.new(file, 'r')
      file_content = ''
      find_file_head(file).times {file_content << f.readline } # insert file head
      file_content << header # insert copyright header
      file_content << f.readline until f.eof? # insert rest of file
      if @options[:noop]
        puts file_content
      else
        dir = "#{@options[:outputdir]}/#{File.dirname(f.path)}"
        FileUtils.mkpath dir unless File.directory?(dir) # create folder if not existing
        outputpath = @options[:outputdir] + file
        File.new(outputpath, 'w').write(file_content)
        @inserted_copyright << file # add file to list
      end
    else
      @unknown_files << file # add file to list of files with unknown type
    end
  end

  # get filetype from file
  def filetype(file) 
    ext = File.extname(file)
    @@extension_types.keys.detect{|key| @@extension_types[key].include?(ext)} || :unknown
  end

  # get hash with comment syntax by filetype
  def comment_syntax_type(type)
    comment_syntax(*@@syntax_types[type]) # Use elements of array as arguments
  end

  # get hash with comment syntax with specified syntax
  def comment_syntax(comm_start = '#', comm_line = '#', comm_end = '')
    { :start => comm_start + " | # #{@@COPYRIGHT_HEADER_START} #",
      :line => comm_line + "|  ",
      :end => comm_line + "| # #{@@COPYRIGHT_HEADER_END} # \n" + comm_end, # comm_end on new line, otherwise it's commented out by comm_line
      :comm_end => comm_end # Needed when cleaning
    }
  end

  # Check file for existing copyright / license in first lines
  def copyright_check(file, lines = 10)
    f = File.new(file, 'r')
    has_copyright = false
    fsize = File.readlines(file).size
    lines = fsize if (fsize < lines)
    lines.times do
      line = f.readline
      has_copyright ||= (/[Cc]opyright/ =~ line) # has_copyright = true if pattern found
      has_copyright ||= (/[Ll]icense/ =~ line)
    end
    has_copyright
  end

  # get position of header[:start], header[:end]
  def find_copyright_header(file, lines = 10)
    header = {}
    fsize = File.readlines(file).size
    f = File.new(file, 'r')
    lines = fsize if (fsize < lines) # prevent from searching beyond EOF
    lines.times do
      if (f.readline.include? @@COPYRIGHT_HEADER_START)
        header[:start]=f.lineno  #Line Number of Header Start
        next until (f.readline.include? @@COPYRIGHT_HEADER_END)
        header[:end]=f.lineno
        break # Stop loop when header found
      end
    end
    header
  end
  
  # get list of patterns, that have to be located before Inserting a comment
  def head_patterns_type(type)
    patterns = @@head_patterns[:general]
    patterns.concat(@@head_patterns[:"#{type}"]) if @@head_patterns[:"#{type}"]
    patterns
  end

  # find last line belonging to the file head -> Comments are inserted after that line
  def find_file_head(file, lines = 10)
    head_end = 0
    type = filetype(file)
    head_patts = head_patterns_type(type)
    fsize = File.readlines(file).size
    f = File.new(file, 'r')
    lines = fsize if (fsize < lines) # prevent from searching beyond EOF
    lines.times do
      line = f.readline
      head_patts.each do |pattern| # check line for each pattern
        if (line =~ /#{pattern}/i) # case insensitive matching
          head_end = f.lineno # when pattern found, active line is still in head
          break
        end
      end
    end
    head_end
  end

  # Clean copyright header in file
  def clean_header(file)
    header = find_copyright_header(file)
    syntax = comment_syntax_type(filetype(file))
    if header.any? # only when header found
      f = File.new(file, 'r')
      file_content = ""
      (header[:start]-1).times {file_content << f.readline } # read lines before header
      f.readline while (f.lineno < header[:end]) # jump over every line till header_end
      line = f.readline
      file_content << line unless line.sub(syntax[:comm_end], '').strip.empty? # add first line after header if not empty (after removing comment end syntax)
      line = f.readline
      file_content << line unless line.strip.empty? # add second line after header end if not empty
      file_content << f.readline until f.eof? # read lines after header
      # puts file_content
      File.new(file, 'w').write(file_content)
      @cleaned_copyright << file
    end
  end
  def write_lists
    lists= {
      @inserted_copyright => "Header inserted in following files:",
      @cleaned_copyright => "Header cleaned in following files:",
      @unknown_files => "Ignored files (unknown filetype):",
      @existing_copyright => "WARNING: Existing Copyright found in following files:",
      }
    lists.each do |list, intro| 
      if list.any?
        puts intro
        list.each { |file| puts "  " + file }
        puts
      end
    end
  end
end

# Command line options parser
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
      opts.on( '-a', '--all', 'Insert Header in all Files in current folder and subdirectories' ) do
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
cht = CopyrightHeaderTool.new # New instance of the Tool
cht.options = OptionParser.parse(ARGV)


# Clean Copyright if option set
cht.clean_header(cht.options[:clean]) if cht.options[:clean]
# Insert Copyright in specific file
cht.insert_header(cht.options[:file]) if cht.options[:file]
# Insert Copyright in all files
cht.insert_all(Dir.pwd) if cht.options[:all]
# Clean Copyright in all files
cht.clean_all(Dir.pwd) if cht.options[:clean_all]

cht.write_lists