module Representable
  StopOnNotFound = -> (fragment, doc, binding, *) do
    return Pipeline::Stop if fragment == Binding::FragmentNotFound
    fragment
  end
  StopOnNil = -> (fragment, doc, binding, *) do # DISCUSS: Not tested/used, yet.
    return Pipeline::Stop if fragment.nil?
    fragment
  end
  OverwriteOnNil = -> (fragment:, doc:, binding:, **opts) do
    if fragment.nil?
      Setter.(fragment: fragment, doc: doc, binding: binding)
      return Pipeline::Stop
    end
    fragment
  end


  # FIXME: how to combine those two guys?
  Default = ->(fragment:, binding:, **opts) do
    if fragment == Binding::FragmentNotFound
      return Pipeline::Stop unless binding.has_default?
      return binding[:default]
    end
  end

  SkipParse = ->(fragment:, binding:, **o) do
    Pipeline::Stop if binding.evaluate_option(:skip_parse, fragment)
  end


  # ->(fragment)=> [fragment, object]
  # Instance = ->(fragment, doc, binding,*args) do
  Instance = ->(opts, *args) do
    puts "@@@@@Instance #{opts[:fragment].inspect}"
    return opts[:binding].evaluate_option(:instance, opts[:fragment], *args)


    [fragment, bla=binding.evaluate_option(:instance, fragment, *args)]

    puts "after Instance: #{fragment} #{bla}"
[fragment, bla]
  end

  # ->(fragment, object)=> object
  # Deserialize = ->(args, doc, binding,*) do
  Deserialize = ->(args, *) do
    # puts "Deser: #{args.inspect}"
    # fragment, object = args
    args[:binding].send(:deserializer).call(args[:fragment], args[:result]) # object.from_hash

    args
  end
  ResolveBecauseDeserializeIsNotHereAndIShouldFixThis = -> (args, doc, binding,*) do
    fragment, object = args
    object
  end

  module Function
    class CreateObject
      def call(fragment, doc, binding,*args)
        object = instance_for(fragment, binding, *args) || class_for(fragment, binding, *args)
        [fragment, object]
      end

    private
      def class_for(fragment, binding, *args)
        item_class = class_from(fragment, binding, *args) or raise DeserializeError.new(":class did not return class constant.")
        item_class.new
      end

      def class_from(fragment, binding, *args)
        binding.evaluate_option(:class, fragment, *args)
      end

      def instance_for(fragment, binding, *args)
        Instance.(fragment, nil, binding, *args).last
      end
    end
  end

  CreateObject = Function::CreateObject.new

  Prepare = ->(result:, binding:, **bla) do
    representer = binding.send(:deserializer).send(:prepare, result)
    # raise args.inspect
    representer
  end

  # FIXME: only add when :parse_filter!
  ParseFilter = ->(fragment:, doc:, binding:, **o) do
    binding.parse_filter(fragment, doc) # FIXME: nested pipeline!
  end

  # Setter = ->(value, doc, binding,*) do
  Setter = ->(binding:, result:, **o) do
    binding.set(result)
  end


  class Collect
    def self.[](*functions)
      new(functions)
    end

    def initialize(functions)
      @item_pipeline = Pipeline[*functions]
    end

    def call(args)
      arr = [] # FIXME : THIS happens in collection deserializer.
      args[:fragment].each_with_index do |item_fragment, i|
        # DISCUSS: we should replace fragment into the existing hash
        result = @item_pipeline.(nil, {fragment: item_fragment, doc: args[:doc], binding: args[:binding]}, i)
        puts "resuuuuult: #{result}"
        return Pipeline::Stop if result == Pipeline::Stop
        arr << result
      end

      arr
    end


    class Hash < self
      def call(fragment, doc, binding)
        {}.tap do |hsh|
          fragment.each { |key, item_fragment| hsh[key] = @item_pipeline.(nil, item_fragment, doc, binding) }
        end
      end
    end
  end
end