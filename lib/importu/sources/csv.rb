require "csv"

require "importu/exceptions"
require "importu/sources"

class Importu::Sources::CSV
  attr_reader :outfile

  def initialize(infile, csv_options: {}, **)
    @infile = infile.respond_to?(:readline) ? infile : File.open(infile, "rb")

    @csv_options = {
      headers:        true,
      return_headers: true,
      write_headers:  true,
      skip_blanks:    true,
    }.merge(csv_options)

    begin
      @reader = ::CSV.new(@infile, @csv_options)
      @header = @reader.readline
    rescue CSV::MalformedCSVError => ex
      raise Importu::InvalidInput, ex.message
    end

    @data_pos = @infile.pos

    if @header.nil?
      raise Importu::InvalidInput, "Empty document"
    end
  end

  def rows
    @infile.pos = @data_pos
    Enumerator.new do |yielder|
      @reader.each {|row| yielder.yield(row.to_hash, row) }
    end
  end

  def wrap_import_record(record, &block)
    begin
      yield
    rescue Importu::MissingField => e
      # if one record missing field, all are, major error
      raise Importu::InvalidInput, "missing required field: #{e.message}"
    rescue Importu::InvalidRecord => e
      write_error(record.raw_data, e.message)
    end
  end

  private def write_error(data, msg)
    unless @writer
      @outfile = Tempfile.new("import")
      @writer = ::CSV.new(@outfile, @csv_options)
      @header["_errors"] = "_errors"
      @writer << @header
    end

    data["_errors"] = msg
    @writer << data
  end

end
