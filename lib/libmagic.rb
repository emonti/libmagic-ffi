# frozen_string_literal: true

require 'ffi'

# LibMagic is ruby FFI bindings for the libmagic native library
module LibMagic
  extend FFI::Library

  begin
    ffi_lib 'magic'
  rescue LoadError
    begin
      ffi_lib 'libmagic'
    rescue LoadError
      begin
        ffi_lib 'libmagic.so'
      rescue LoadError
        ffi_lib 'libmagic.so.1'
      end
    end
  end

  # Magic flags constants
  MAGIC_NONE              = 0x000000  # No flags
  MAGIC_DEBUG             = 0x000001  # Turn on debugging
  MAGIC_SYMLINK           = 0x000002  # Follow symlinks
  MAGIC_COMPRESS          = 0x000004  # Check inside compressed files
  MAGIC_DEVICES           = 0x000008  # Look at the contents of devices
  MAGIC_MIME_TYPE         = 0x000010  # Return the MIME type
  MAGIC_CONTINUE          = 0x000020  # Return all matches
  MAGIC_CHECK             = 0x000040  # Print warnings to stderr
  MAGIC_PRESERVE_ATIME    = 0x000080  # Restore access time on exit
  MAGIC_RAW               = 0x000100  # Don't translate unprintable chars
  MAGIC_ERROR             = 0x000200  # Handle ENOENT etc as real errors
  MAGIC_MIME_ENCODING     = 0x000400  # Return the MIME encoding
  MAGIC_MIME              = (MAGIC_MIME_TYPE | MAGIC_MIME_ENCODING)
  MAGIC_APPLE             = 0x000800  # Return the Apple creator and type
  MAGIC_EXTENSION         = 0x001000  # Return a /-separated list of extensions
  MAGIC_COMPRESS_TRANSP   = 0x002000  # Check inside compressed files but not report compression
  MAGIC_NO_CHECK_COMPRESS = 0x004000  # Don't check for compressed files
  MAGIC_NO_CHECK_TAR      = 0x008000  # Don't check for tar files
  MAGIC_NO_CHECK_SOFT     = 0x010000  # Don't check magic entries
  MAGIC_NO_CHECK_APPTYPE  = 0x020000  # Don't check application type
  MAGIC_NO_CHECK_ELF      = 0x040000  # Don't check for elf details
  MAGIC_NO_CHECK_TEXT     = 0x080000  # Don't check for text files
  MAGIC_NO_CHECK_CDF      = 0x100000  # Don't check for cdf files
  MAGIC_NO_CHECK_TOKENS   = 0x200000  # Don't check tokens
  MAGIC_NO_CHECK_ENCODING = 0x400000  # Don't check text encodings

  # Magic context type (opaque pointer)
  typedef :pointer, :magic_t

  # Core libmagic functions
  attach_function :magic_open, [:int], :magic_t
  attach_function :magic_close, [:magic_t], :void
  attach_function :magic_getpath, %i[string int], :string
  attach_function :magic_file, %i[magic_t string], :string
  attach_function :magic_descriptor, %i[magic_t int], :string
  attach_function :magic_buffer, %i[magic_t pointer size_t], :string
  attach_function :magic_error, [:magic_t], :string
  attach_function :magic_setflags, %i[magic_t int], :int
  attach_function :magic_version, [], :int
  attach_function :magic_load, %i[magic_t string], :int
  attach_function :magic_compile, %i[magic_t string], :int
  attach_function :magic_check, %i[magic_t string], :int
  attach_function :magic_list, %i[magic_t string], :int
  attach_function :magic_errno, [:magic_t], :int

  class MagicError < RuntimeError
  end

  # LibMagic::Magic
  class Magic
    # MagicT is a wrapper around the ffi pointer used internally by the library
    class MagicT
      attr_reader :closed

      def initialize(pointer)
        @pointer = pointer
        @closed = false
      end

      def closed?
        (@closed or @pointer.null?)
      end

      def pointer
        raise MagicError, 'Attempt to use a freed/closed magic context pointer' if closed?

        @pointer
      end

      def close
        unless closed?
          LibMagic.magic_close(@pointer)
          @pointer = FFI::Pointer::NULL
          @closed = true
        end
        nil
      end
    end

    attr_reader :flags

    def initialize(flags = MAGIC_NONE, path = nil)
      @flags = flags
      p = LibMagic.magic_open(flags)

      raise MagicError, 'Unable to initialize magic context' if p.null?

      # Load default magic database
      if LibMagic.magic_load(p, path) != 0
        error_msg = LibMagic.magic_error(p)
        LibMagic.magic_close(p)
        raise MagicError, "Unable to load magic database: #{error_msg}"
      end

      @context = MagicT.new(p)

      # Set up finalizer to clean up context
      ObjectSpace.define_finalizer(self, self.class.finalizer(@context))
    end

    def self.finalizer(context)
      proc { context.close }
    end

    def file(path)
      raise MagicError, "Nonexistant file: #{path}" unless File.exist?(path)

      result = LibMagic.magic_file(ctx_pointer, path)
      handle_result(result)
    end

    def buffer(data)
      raise ArgumentError, 'Data must be a String' unless data.is_a?(String)

      buffer_ptr = FFI::MemoryPointer.new(:char, data.bytesize)
      buffer_ptr.put_bytes(0, data)
      result = LibMagic.magic_buffer(ctx_pointer, buffer_ptr, data.bytesize)

      handle_result(result)
    end

    def descriptor(ifd)
      result = LibMagic.magic_descriptor(ctx_pointer, ifd)
      handle_result(result)
    end

    def setflags(flags)
      @flags = flags
      result = LibMagic.magic_setflags(ctx_pointer, flags)
      raise MagicError, "Unable to set flags: #{error}" if result.negative?

      result
    end

    def flags=(new_flags)
      setflags(new_flags)
    end

    def error
      LibMagic.magic_error(ctx_pointer)
    end

    def errno
      LibMagic.magic_errno(ctx_pointer)
    end

    def load(path = nil)
      result = LibMagic.magic_load(ctx_pointer, path)
      handle_result(result, fail_msg: 'Unable to load magic database')
      result
    end

    def compile(path)
      result = LibMagic.magic_compile(ctx_pointer, path)
      handle_result(result, fail_msg: 'Unable to compile magic database')
    end

    def check(path)
      result = LibMagic.magic_check(ctx_pointer, path)
      handle_result(result, fail_msg: 'Magic database check failed')
      result
    end

    def list(path)
      result = LibMagic.magic_list(ctx_pointer, path)
      handle_result(result, fail_msg: 'Unable to list magic database')
      result
    end

    def close
      @context.close
    end

    private

    def handle_result(result, fail_msg: nil)
      if result.nil?
        fail_msg ||= 'Magic operation failed'
        error_msg = "#{fail_msg}: #{error}"
        raise MagicError, "Magic operation failed: #{error_msg}"
      end
      result
    end

    def ctx_pointer
      return @context.pointer if @context&.pointer && !@context.closed

      raise MagicError, 'Attempt to use freed or uninitialized magic context pointer'
    end
  end

  # Convenience module methods
  #
  module_function

  def version
    LibMagic.magic_version
  end

  def file(path, flags = MAGIC_NONE)
    magic = Magic.new(flags)
    begin
      magic.file(path)
    ensure
      magic.close
    end
  end

  def buffer(data, flags = MAGIC_NONE)
    magic = Magic.new(flags)
    begin
      magic.buffer(data)
    ensure
      magic.close
    end
  end

  def mime_type(path)
    file(path, MAGIC_MIME_TYPE)
  end

  def mime_type_buffer(buf)
    buffer(buf, MAGIC_MIME_TYPE)
  end

  def mime_encoding(path)
    file(path, MAGIC_MIME_ENCODING)
  end

  def mime_encoding_buffer(buf)
    buffer(buf, MAGIC_MIME_ENCODING)
  end

  def mime(path)
    file(path, MAGIC_MIME)
  end

  def mime_buffer(buf)
    buffer(buf, MAGIC_MIME)
  end
end
