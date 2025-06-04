# libmagic-ffi

Ruby FFI bindings for libmagic, providing file type detection and MIME type identification using the battle-tested libmagic library.

## Features

- **Cross-platform compatibility** - Works on CRuby (MRI), JRuby, TruffleRuby, and Rubinius
- **No compilation required** - Pure Ruby FFI implementation
- **Comprehensive API** - Both high-level convenience methods and low-level library access
- **Memory safe** - Automatic resource management with finalizers
- **Full libmagic feature support** - All flags and functions available

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'libmagic-ffi'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install libmagic-ffi

### System Dependencies

You'll need libmagic installed on your system:

**Ubuntu/Debian:**
```bash
sudo apt-get install libmagic-dev
```

**macOS:**
```bash
brew install libmagic
```

**CentOS/RHEL/Fedora:**
```bash
sudo yum install file-devel
# or on newer systems:
sudo dnf install file-devel
```

**Windows:**
- Install libmagic through MSYS2 or compile from source
- Ensure the library is in your PATH

## Quick Start

```ruby
require 'libmagic-ffi'

# Detect file type
LibMagic.file('/path/to/file.pdf')
# => "PDF document, version 1.4"

# Get MIME type
LibMagic.mime_type('/path/to/image.jpg')
# => "image/jpeg"

# Detect from buffer
data = File.read('document.docx')
LibMagic.buffer(data)
# => "Microsoft Word 2007+"
```

## Usage

### Simple File Detection

```ruby
# File description
LibMagic.file('/etc/passwd')
# => "ASCII text"

# MIME type only
LibMagic.mime_type('/home/user/photo.png')
# => "image/png"

# MIME encoding
LibMagic.mime_encoding('/home/user/document.txt')
# => "us-ascii"

# Full MIME information
LibMagic.mime('/home/user/archive.tar.gz')
# => "application/gzip; charset=binary"
```

### Buffer Detection

```ruby
# From string data
pdf_header = "%PDF-1.4\n%âãÏÓ"
LibMagic.buffer(pdf_header)
# => "PDF document, version 1.4"

# From file data
image_data = File.read('image.jpg')
LibMagic.mime_type(image_data)
# => "image/jpeg"
```

### Advanced Usage with Magic Objects

```ruby
# Create a magic object with specific flags
magic = LibMagic::Magic.new(LibMagic::MAGIC_MIME_TYPE)

# Use it for multiple operations
magic.file('/path/to/file1')
magic.file('/path/to/file2')
magic.buffer(some_data)

# Don't forget to close (or use a finalizer)
magic.close
```

### Using Different Flags

```ruby
# Get file extensions
LibMagic.file('/path/to/archive.tar.gz', LibMagic::MAGIC_EXTENSION)
# => "tar.gz/tgz/taz"

# Follow symlinks
LibMagic.file('/path/to/symlink', LibMagic::MAGIC_SYMLINK)

# Combine flags
flags = LibMagic::MAGIC_MIME_TYPE | LibMagic::MAGIC_SYMLINK
LibMagic.file('/path/to/file', flags)
```

## Available Flags

| Flag | Description |
|------|-------------|
| `MAGIC_NONE` | No special handling (default) |
| `MAGIC_MIME_TYPE` | Return MIME type |
| `MAGIC_MIME_ENCODING` | Return MIME encoding |
| `MAGIC_MIME` | Return both MIME type and encoding |
| `MAGIC_SYMLINK` | Follow symbolic links |
| `MAGIC_COMPRESS` | Check inside compressed files |
| `MAGIC_DEVICES` | Look at device files |
| `MAGIC_CONTINUE` | Return all matches |
| `MAGIC_CHECK` | Print warnings to stderr |
| `MAGIC_RAW` | Don't translate unprintable characters |
| `MAGIC_EXTENSION` | Return file extensions |
| `MAGIC_APPLE` | Return Apple creator/type |

See the source code for the complete list of available flags.

## API Reference

### Module Methods

#### `LibMagic.file(path, flags = MAGIC_NONE)`
Detect file type from file path.

#### `LibMagic.buffer(data, flags = MAGIC_NONE)`
Detect file type from data buffer.

#### `LibMagic.mime_type(path_or_data)`
Get MIME type (automatically detects if input is path or data).

#### `LibMagic.mime_encoding(path_or_data)`
Get MIME encoding.

#### `LibMagic.mime(path_or_data)`
Get full MIME information.

#### `LibMagic.version`
Get libmagic version number.

### Magic Class

#### `Magic.new(flags = MAGIC_NONE)`
Create a new Magic object with specified flags.

#### `#file(path)`
Detect file type from path.

#### `#buffer(data)`
Detect file type from data buffer.

#### `#descriptor(fd)`
Detect file type from file descriptor.

#### `#setflags(flags)` / `#flags=(flags)`
Change detection flags.

#### `#close`
Close the magic object and free resources.

## Error Handling

The library raises `RuntimeError` exceptions for libmagic errors:

```ruby
begin
  result = LibMagic.file('/nonexistent/file')
rescue RuntimeError => e
  puts "Error: #{e.message}"
end
```

## Thread Safety

Each `Magic` object should be used by only one thread at a time. For multi-threaded applications, create separate `Magic` instances per thread or use the module-level convenience methods which create temporary objects.

## Performance Notes

- Module-level methods (`LibMagic.file`, `LibMagic.buffer`) create and destroy Magic objects for each call
- For multiple operations, reuse a `Magic` object for better performance
- FFI calls have some overhead compared to native C extensions, but this is negligible for most use cases

## Examples

### Batch File Processing

```ruby
magic = LibMagic::Magic.new(LibMagic::MAGIC_MIME_TYPE)

Dir.glob('/path/to/files/*').each do |file|
  next unless File.file?(file)
  
  mime_type = magic.file(file)
  puts "#{File.basename(file)}: #{mime_type}"
end

magic.close
```

### Web Upload Validation

```ruby
def validate_upload(file_data, allowed_types)
  detected_type = LibMagic.mime_type(file_data)
  
  unless allowed_types.include?(detected_type)
    raise "Invalid file type: #{detected_type}"
  end
  
  detected_type
end

# Usage
allowed = ['image/jpeg', 'image/png', 'image/gif']
file_type = validate_upload(uploaded_data, allowed)
```

### Archive Content Detection

```ruby
# Detect content inside compressed files
magic = LibMagic::Magic.new(LibMagic::MAGIC_COMPRESS)
result = magic.file('archive.tar.gz')
magic.close

puts result  # Will show information about files inside the archive
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yourusername/libmagic-ffi.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt.

To install this gem onto your local machine, run `bundle exec rake install`.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Changelog

### 1.0.0
- Initial release
