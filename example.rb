# frozen_string_literal: true

require 'libmagic'

puts "LibMagic Version: #{LibMagic.version}"
puts

# Example 1: Simple file detection
puts '=== File Type Detection ==='
if File.exist?('/etc/passwd')
  puts 'File: /etc/passwd'
  puts "Type: #{LibMagic.file('/etc/passwd')}"
  puts "MIME: #{LibMagic.mime('/etc/passwd')}"
  puts
end

# Example 2: Buffer detection
puts '=== Buffer Detection ==='
pdf_header = '%PDF-1.4'
puts "Buffer: #{pdf_header.inspect}"
puts "Type: #{LibMagic.buffer(pdf_header)}"
puts "MIME: #{LibMagic.mime(pdf_header)}"
puts

# Example 3: Using Magic object for multiple operations
puts '=== Magic Object Example ==='
magic = LibMagic::Magic.new(LibMagic::MAGIC_MIME_TYPE)

test_files = ['/bin/ls', '/etc/hosts', __FILE__]
test_files.each do |file|
  next unless File.exist?(file)

  puts "#{file}: #{magic.file(file)}"
end

magic.close
puts

# Example 4: Different flag combinations
puts '=== Different Flags ==='
if File.exist?(__FILE__)
  puts "This file (#{__FILE__}):"
  puts "  Description: #{LibMagic.file(__FILE__, LibMagic::MAGIC_NONE)}"
  puts "  MIME Type: #{LibMagic.file(__FILE__, LibMagic::MAGIC_MIME_TYPE)}"
  puts "  MIME Encoding: #{LibMagic.file(__FILE__, LibMagic::MAGIC_MIME_ENCODING)}"
  puts "  Extensions: #{LibMagic.file(__FILE__, LibMagic::MAGIC_EXTENSION)}"
end
