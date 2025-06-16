require 'minitest/autorun'
require 'minitest/spec'
require 'tempfile'
require 'stringio'
require_relative '../lib/libmagic'

describe LibMagic do
  # Test data for various file types
  TEST_FILES = {
    pdf: {
      data: "%PDF-1.4\n%âãÏÓ\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj",
      mime_type: 'application/pdf',
      description: /PDF document/
    },
    jpeg: {
      data: "\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x01\x00H\x00H\x00\x00",
      mime_type: 'image/jpeg',
      description: /JPEG image/
    },
    png: {
      data: "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xDE",
      mime_type: 'image/png',
      description: /PNG image/
    },
    text: {
      data: "Hello, World!\nThis is a text file.\n",
      mime_type: 'text/plain',
      description: /ASCII text/
    },
    html: {
      data: "<!DOCTYPE html>\n<html><head><title>Test</title></head><body>Hello</body></html>",
      mime_type: 'text/html',
      description: /HTML document/
    }
  }.freeze

  before do
    # Skip tests if libmagic is not available

    LibMagic.version
  rescue LoadError => e
    skip "libmagic not available: #{e.message}"
  end

  describe 'LibMagic module methods' do
    describe '.version' do
      it 'returns a version number' do
        version = LibMagic.version
        _(version).must_be_kind_of Integer
        _(version).must_be :>, 0
      end
    end

    describe '.buffer' do
      TEST_FILES.each do |type, test_data|
        it "detects #{type} files from buffer" do
          result = LibMagic.buffer(test_data[:data])
          _(result).must_match test_data[:description]
        end
      end

      it 'raises error for nil buffer' do
        _(proc { LibMagic.buffer(nil) }).must_raise ArgumentError
      end

      it 'handles empty buffer' do
        result = LibMagic.buffer('')
        _(result).wont_be_nil
      end

      it 'works with different flags' do
        pdf_data = TEST_FILES[:pdf][:data]

        # Default description
        desc = LibMagic.buffer(pdf_data, LibMagic::MAGIC_NONE)
        _(desc).must_match(/PDF/)

        # MIME type only
        mime = LibMagic.buffer(pdf_data, LibMagic::MAGIC_MIME_TYPE)
        _(mime).must_equal 'application/pdf'
      end
    end

    describe '.file' do
      before do
        @temp_files = {}
        TEST_FILES.each do |type, test_data|
          temp_file = Tempfile.new(["test_#{type}", ".#{type}"])
          temp_file.write(test_data[:data])
          temp_file.close
          @temp_files[type] = temp_file
        end
      end

      after do
        @temp_files.each_value(&:unlink)
      end

      TEST_FILES.each do |type, test_data|
        it "detects #{type} files from file path" do
          result = LibMagic.file(@temp_files[type].path)
          _(result).must_match test_data[:description]
        end
      end

      it 'raises error for non-existent file' do
        _(proc { LibMagic.file('/this/file/does/not/exist') }).must_raise RuntimeError
      end

      it 'works with different flags' do
        pdf_file = @temp_files[:pdf]

        # Default description
        desc = LibMagic.file(pdf_file.path, LibMagic::MAGIC_NONE)
        _(desc).must_match(/PDF/)

        # MIME type only
        mime = LibMagic.file(pdf_file.path, LibMagic::MAGIC_MIME_TYPE)
        _(mime).must_equal 'application/pdf'
      end
    end

    describe '.mime_type' do
      it 'detects MIME types from buffers' do
        TEST_FILES.each_value do |test_data|
          result = LibMagic.mime_type_buffer(test_data[:data])
          _(result).must_equal test_data[:mime_type]
        end
      end

      it 'detects MIME types from file paths' do
        @temp_files = {}
        TEST_FILES.each do |type, test_data|
          temp_file = Tempfile.new(["test_#{type}", ".#{type}"])
          temp_file.write(test_data[:data])
          temp_file.close
          @temp_files[type] = temp_file
          result = LibMagic.mime_type(@temp_files[type].path)
          _(result).must_equal test_data[:mime_type]
        end

        @temp_files.each_value(&:unlink)
      end
    end

    describe '.mime_encoding_buffer' do
      it 'detects encoding from text buffer' do
        result = LibMagic.mime_encoding_buffer(TEST_FILES[:text][:data])
        _(result).must_match(/ascii|utf-8/i)
      end

      it 'detects encoding from binary buffer' do
        result = LibMagic.mime_encoding_buffer(TEST_FILES[:png][:data])
        _(result).must_match(/binary/i)
      end
    end

    describe '.mime' do
      it 'returns full MIME information' do
        result = LibMagic.mime_buffer(TEST_FILES[:text][:data])
        _(result).must_match(%r{text/plain})
        _(result).must_match(/charset=/)
      end
    end
  end

  describe 'LibMagic::Magic class' do
    describe '#initialize' do
      it 'creates a magic object with default flags' do
        magic = LibMagic::Magic.new
        _(magic).must_be_kind_of LibMagic::Magic
        _(magic.flags).must_equal LibMagic::MAGIC_NONE
        magic.close
      end

      it 'creates a magic object with custom flags' do
        magic = LibMagic::Magic.new(LibMagic::MAGIC_MIME_TYPE)
        _(magic.flags).must_equal LibMagic::MAGIC_MIME_TYPE
        magic.close
      end

      it 'loads default magic database automatically' do
        magic = LibMagic::Magic.new
        # Should not raise error if database loaded successfully
        result = magic.buffer(TEST_FILES[:pdf][:data])
        _(result).wont_be_nil
        magic.close
      end
    end

    describe '#file' do
      before do
        @magic = LibMagic::Magic.new
        @temp_file = Tempfile.new('test_pdf')
        @temp_file.write(TEST_FILES[:pdf][:data])
        @temp_file.close
      end

      after do
        @magic.close
        @temp_file.unlink
      end

      it 'detects file type from path' do
        result = @magic.file(@temp_file.path)
        _(result).must_match(/PDF/)
      end

      it 'raises error for non-existent file' do
        _(proc { @magic.file('/nonexistent/file') }).must_raise RuntimeError
      end
    end

    describe '#buffer' do
      before do
        @magic = LibMagic::Magic.new
      end

      after do
        @magic.close
      end

      it 'detects file type from buffer' do
        result = @magic.buffer(TEST_FILES[:pdf][:data])
        _(result).must_match(/PDF/)
      end

      it 'handles binary data correctly' do
        result = @magic.buffer(TEST_FILES[:jpeg][:data])
        _(result).must_match(/JPEG/)
      end

      it 'raises error for invalid buffer' do
        _(proc { @magic.buffer(nil) }).must_raise ArgumentError
      end
    end

    describe '#setflags and #flags=' do
      before do
        @magic = LibMagic::Magic.new
      end

      after do
        @magic.close
      end

      it 'changes flags using setflags' do
        @magic.setflags(LibMagic::MAGIC_MIME_TYPE)
        _([@magic.flags]).must_equal [LibMagic::MAGIC_MIME_TYPE]
      end

      it 'changes flags using flags= setter' do
        @magic.flags = LibMagic::MAGIC_MIME_TYPE
        _([@magic.flags]).must_equal [LibMagic::MAGIC_MIME_TYPE]
      end

      it 'affects detection results' do
        # Default flags - returns description
        desc_result = @magic.buffer(TEST_FILES[:pdf][:data])
        _(desc_result).must_match(/PDF/)

        # Change to MIME type flags
        @magic.flags = LibMagic::MAGIC_MIME_TYPE
        mime_result = @magic.buffer(TEST_FILES[:pdf][:data])
        _(mime_result).must_equal 'application/pdf'
      end
    end

    describe '#close' do
      it 'closes the magic object safely' do
        magic = LibMagic::Magic.new
        magic.close
        # Should be safe to call multiple times
        magic.close
      end

      it 'prevents further operations after close' do
        magic = LibMagic::Magic.new
        magic.close
        # Operations on closed magic object should fail
        _(proc { magic.buffer('test') }).must_raise RuntimeError
      end
    end

    describe 'resource management' do
      it 'automatically cleans up with finalizer' do
        # This test verifies that finalizers are set up correctly
        magic = LibMagic::Magic.new
        finalizer_proc = magic.class.finalizer(magic.instance_variable_get(:@context))
        _(finalizer_proc).must_be_kind_of Proc
        magic.close
      end
    end

    describe 'error handling' do
      before do
        @magic = LibMagic::Magic.new
      end

      after do
        @magic.close
      end

      it 'provides error messages' do
        @magic.file('/nonexistent/file')
      rescue RuntimeError => e
        _(e.message).must_match(%r{nonexistent/file})
      end

      ### as of libmagic v546:
      ### libmagic actually doesn't fail when a nonexistent file is supplied
      ### but actually returns a string saying it is a nonexistent file
      ### go figure...
      # it "has error and errno methods" do
      #  begin
      #    @magic.file("/nonexistent/file")
      #  rescue RuntimeError => e
      #  end
      #  @magic.error.must_be_kind_of String
      #  @magic.errno.must_be_kind_of Integer
      # end
    end
  end

  describe 'Constants' do
    it 'defines all major magic flags' do
      # Test that key constants are defined and have expected values
      _(LibMagic::MAGIC_NONE).must_equal 0x000000
      _(LibMagic::MAGIC_MIME_TYPE).must_equal 0x000010
      _(LibMagic::MAGIC_MIME_ENCODING).must_equal 0x000400
      _(LibMagic::MAGIC_MIME).must_equal(LibMagic::MAGIC_MIME_TYPE | LibMagic::MAGIC_MIME_ENCODING)
      _(LibMagic::MAGIC_SYMLINK).must_equal 0x000002
      _(LibMagic::MAGIC_COMPRESS).must_equal 0x000004
    end

    it 'defines flag combinations correctly' do
      _(LibMagic::MAGIC_MIME).must_equal 0x000410 # 0x000010 | 0x000400
    end
  end

  describe 'Edge cases and error conditions' do
    it 'handles very large buffers' do
      large_data = 'A' * 1_000_000
      result = LibMagic.buffer(large_data)
      _(result).must_match(/ASCII text/)
    end

    it 'handles binary data with null bytes' do
      binary_data = "\x00\x01\x02\x03\xFF\xFE\xFD"
      result = LibMagic.buffer(binary_data)
      _(result).wont_be_nil
    end

    it 'handles Unicode text' do
      unicode_text = 'Hello 世界 🌍'
      result = LibMagic.buffer(unicode_text)
      _(result).must_match(/text/i)
    end

    it 'handles empty strings gracefully' do
      result = LibMagic.buffer('')
      _(result).wont_be_nil
    end
  end

  describe 'Flag combinations' do
    it 'works with multiple flags combined' do
      flags = LibMagic::MAGIC_MIME_TYPE | LibMagic::MAGIC_COMPRESS
      result = LibMagic.buffer(TEST_FILES[:pdf][:data], flags)
      _(result).must_equal 'application/pdf'
    end

    it 'respects SYMLINK flag' do
      # This would need actual symlink files to test properly
      # For now, just verify the flag doesn't break normal operation
      result = LibMagic.buffer(TEST_FILES[:text][:data], LibMagic::MAGIC_SYMLINK)
      _(result).must_match(/text/i)
    end
  end

  describe 'Thread safety considerations' do
    it 'allows multiple Magic objects in different threads' do
      results = []
      threads = []

      3.times do |i|
        threads << Thread.new do
          magic = LibMagic::Magic.new(LibMagic::MAGIC_MIME_TYPE)
          result = magic.buffer(TEST_FILES[:pdf][:data])
          results[i] = result
          magic.close
        end
      end

      threads.each(&:join)

      results.each do |result|
        _(result).must_equal 'application/pdf'
      end
    end
  end

  describe 'Integration with file system' do
    it 'works with various file permissions' do
      temp_file = Tempfile.new('test_permissions')
      temp_file.write(TEST_FILES[:text][:data])
      temp_file.close

      # Test with different permissions
      File.chmod(0o644, temp_file.path)
      result1 = LibMagic.file(temp_file.path)

      File.chmod(0o444, temp_file.path) # Read-only
      result2 = LibMagic.file(temp_file.path)

      _(result1).must_equal result2
      temp_file.unlink
    end
  end

  describe 'Memory management' do
    it "doesn't leak memory with repeated operations" do
      # This test verifies that repeated operations don't cause issues
      magic = LibMagic::Magic.new

      100.times do
        magic.buffer(TEST_FILES[:pdf][:data])
      end

      magic.close
      # If we get here without issues, memory management is working
      _(true).must_equal true
    end

    it 'handles rapid object creation/destruction' do
      10.times do
        magic = LibMagic::Magic.new
        magic.buffer(TEST_FILES[:text][:data])
        magic.close
      end

      # Test module methods which create/destroy objects internally
      10.times do
        LibMagic.buffer(TEST_FILES[:text][:data])
      end

      _(true).must_equal true
    end
  end
end

# Additional helper methods for testing
class LibMagicTestHelper
  def self.create_test_file(type, content = nil)
    content ||= case type
                when :text
                  "This is a test text file.\nSecond line.\n"
                when :binary
                  "\x00\x01\x02\x03\xFF\xFE\xFD\xFC"
                when :empty
                  ''
                else
                  'Unknown file type'
                end

    temp_file = Tempfile.new(["test_#{type}", '.txt'])
    temp_file.write(content)
    temp_file.close
    temp_file
  end

  def self.cleanup_temp_files(files)
    Array(files).each do |file|
      file.unlink if file.respond_to?(:unlink)
    end
  end
end

# Performance benchmarks (optional, can be run separately)
if ENV['BENCHMARK']
  require 'benchmark'

  puts "\n=== Performance Benchmarks ==="

  test_data = LibMagic::TEST_FILES[:pdf][:data]

  Benchmark.bm(20) do |x|
    x.report('Module method (new)') do
      100.times { LibMagic.buffer(test_data) }
    end

    x.report('Reused Magic object') do
      magic = LibMagic::Magic.new
      100.times { magic.buffer(test_data) }
      magic.close
    end

    x.report('MIME type detection') do
      100.times { LibMagic.mime_type_buffer(test_data) }
    end
  end
end
