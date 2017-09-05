require "tempfile"

require "importu/backends"
require "importu/converters"
require "importu/dsl"
require "importu/exceptions"
require "importu/summary"

class Importu::Importer

  include Importu::Dsl
  include Importu::Converters

  attr_reader :source

  def initialize(source)
    @source = source
  end

  def definition
    self.class
  end

  def import!(&block)
    @summary = nil # Reset counters
    records.each do |record|
      source.wrap_import_record(record) do
        import_record(record, &block)
      end
    end
    summary
  end

  def records
    @source.records(definition)
  end

  def summary
    @summary ||= Importu::Summary.new
  end

  private def enforce_allowed_actions!(action)
    if action == :create && !allowed_actions.include?(:create)
      raise Importu::InvalidRecord, "#{model} not found"
    elsif action == :update && !allowed_actions.include?(:update)
      raise Importu::InvalidRecord, "existing #{model} found"
    end
  end

  private def import_record(record, &block)
    begin
      object = backend.find(record)

      if object.nil?
        enforce_allowed_actions!(:create)
        result = backend.create(record, &block)
        # FIXME: mark_encountered(object) ?
      else
        enforce_allowed_actions!(:update)
        check_duplicate!(backend, object) # FIXME: Should come before action enforcement?
        result = backend.update(record, object, &block)
        # FIXME: mark_encountered(object) ?
      end

      summary.record(result)

    rescue Importu::InvalidRecord => e
      errors =  e.validation_errors || ["#{e.name}: #{e.message}"]
      summary.record(:invalid, errors: errors)
      raise
    end
  end

  private def check_duplicate!(backend, object)
    object_key = backend.object_key(object) or return
    if ((@encountered||=Hash.new(0))[object_key] += 1) > 1
      raise Importu::DuplicateRecord, "matches a previously imported record"
    end
  end

  private def backend
    @backend ||= begin
      registry = Importu::Backends.registry
      backend_impl = registry.guess_from_definition!(definition)
      backend_impl.new(definition)
    end
  end

end
