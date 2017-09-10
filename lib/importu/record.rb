class Importu::Record

  extend Forwardable

  attr_reader :data

  def initialize(data, context, fields:, **)
    @data = data
    @field_definitions = fields
    @context = context.new(data)
  end

  def assignable_fields_for(action)
    @field_definitions.each_with_object([]) do |(name,definition),acc|
      if definition[action] == true && definition[:abstract] == false
        acc << name
      end
    end
  end

  def to_hash
    @record_hash ||= @field_definitions.each_with_object({}) do |(name,_),hash|
      hash[name] = @context.field_value(name)
    end
  end

  # A record should behave as similarly to a hash as possible, so forward all
  # hash methods not defined on this class to our hash of converted values.
  delegate (Hash.public_instance_methods - public_instance_methods) => :to_hash

end
