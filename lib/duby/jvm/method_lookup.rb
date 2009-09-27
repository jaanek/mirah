module Duby
  module JVM
    module MethodLookup
      # dummy log; it's expected the inclusion target will have it
      def log(msg); end
      
      # def jvm_type(type)
      #   return type if type.kind_of? Java::JavaClass
      #   return type.jvm_type
      # end
      # 
      # def convert_params(params)
      #   params.map {|param| jvm_type(param)}
      # end

      def find_method(mapped_type, name, mapped_params, meta)
        # mapped_type = jvm_type(mapped_type)
        # mapped_params = convert_params(mapped_params)
        raise ArgumentError if mapped_params.any? {|p| p.nil?}
        if name == 'new'
          if meta
            name = "<init>"
            constructor = true
          else
            constructor = false
          end
        end

        begin
          if constructor
            method = mapped_type.constructor(*mapped_params)
          else
            method = mapped_type.java_method(name, *mapped_params)
          end
        rescue NameError
          unless constructor
            # exact args failed, do a deeper search
            log "Failed to locate method #{mapped_type}.#{name}(#{mapped_params})"

            method = find_jls(mapped_type, name, mapped_params, meta)
          end
          unless method
            log "Failed to locate method #{name}(#{mapped_params}) on #{mapped_type}"
            return nil
          end
        end

        log "Found method #{method.declaring_class}.#{name}(#{method.argument_types}) from #{mapped_type}"
        return method
      end
      
      def find_jls(mapped_type, name, mapped_params, meta)
        # mapped_type = jvm_type(mapped_type)
        # mapped_params = convert_params(mapped_params)
        if meta
          all_methods = mapped_type.declared_class_methods
        else
          all_methods = []
          cls = mapped_type
          while cls
            all_methods += cls.declared_instance_methods
            cls = cls.superclass
          end
        end
        by_name = all_methods.select {|m| m.name == name && mapped_params.size <= m.argument_types.size}
        by_name_and_arity = by_name.select {|m| m.argument_types.size == mapped_params.size}

        phase1_methods = phase1(mapped_params, by_name_and_arity)

        if phase1_methods.size > 1
          raise "Ambiguous targets invoking #{mapped_type}.#{name}:\n#{phase1_methods}"
        end

        phase1_methods[0] ||
          phase2(mapped_params, by_name) ||
          phase3(mapped_params, by_name)
      end
        
      def phase1(mapped_params, potentials)
        # cycle through methods looking for more specific matches; gather matches of equal specificity
        methods = potentials.inject([]) do |currents, potential|
          method_params = potential.argument_types
          
          # exact match always wins; duplicates not possible
          return [potential] if each_is_exact(mapped_params, method_params)
          
          # otherwise, check for potential match and compare to current
          # TODO: missing ambiguity check; picks last method of equal specificity
          if each_is_exact_or_subtype_or_convertible(mapped_params, method_params)
            if currents.size > 0
              if is_more_specific?(potential.argument_types, currents[0].argument_types)
                # potential is better, dump all currents
                currents = [potential]
              elsif is_more_specific?(currents[0].argument_types, potential.argument_types)
                # currents are better, try next potential
                #next
              else
                # equal specificity, append to currents
                currents << potential
              end
            else
              # no previous matches, use potential
              currents = [potential]
            end
          end
          
          currents
        end

        methods
      end
      
      def is_more_specific?(potential, current)
        each_is_exact_or_subtype_or_convertible(potential, current)
      end
      
      def phase2(mapped_params, potentials)
        nil
      end
      
      def phase3(mapped_params, potentials)
        nil
      end
      
      def each_is_exact(incoming, target)
        incoming.each_with_index do |in_type, i|
          target_type = target[i]
          
          # exact match
          return false unless target_type == in_type
        end
        return true
      end
      
      def each_is_exact_or_subtype_or_convertible(incoming, target)
        incoming.each_with_index do |in_type, i|
          target_type = target[i]
          
          # exact match
          next if target_type == in_type
          
          # primitive is safely convertible
          if target_type.primitive?
            if in_type.primitive?
              next if primitive_convertible? in_type, target_type
            end
            return false
          end
          
          # object type is assignable
          return false unless target_type.assignable_from? in_type
        end
        return true
      end
      
      BOOLEAN = Java::boolean.java_class
      BYTE = Java::byte.java_class
      SHORT = Java::short.java_class
      CHAR = Java::char.java_class
      INT = Java::int.java_class
      LONG = Java::long.java_class
      FLOAT = Java::float.java_class
      DOUBLE = Java::double.java_class
      
      PrimitiveConversions = {
        BOOLEAN => [BOOLEAN],
        BYTE => [BYTE, SHORT, CHAR, INT, LONG, FLOAT, DOUBLE],
        SHORT => [SHORT, INT, LONG, FLOAT, DOUBLE],
        CHAR => [CHAR, INT, LONG, FLOAT, DOUBLE],
        INT => [INT, LONG, FLOAT, DOUBLE],
        LONG => [LONG, DOUBLE],
        FLOAT => [FLOAT, DOUBLE],
        DOUBLE => [DOUBLE]
      }
      
      def primitive_convertible?(in_type, target_type)
        if PrimitiveConversions.include? in_type
          PrimitiveConversions[in_type].include?(target_type)
        else
          in_type.convertible_to?(target_type)
        end
      end
    end
  end
end