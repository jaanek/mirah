module Duby::AST
  class ClassDefinition < Node
    include Named
    include Scope
    attr_accessor :superclass, :body, :interfaces
        
    def initialize(parent, line_number, name)
      super(parent, line_number)
      @interfaces = []
      @name = name
      if Duby::AST.type_factory.respond_to? :declare_type
        Duby::AST.type_factory.declare_type(self)
      end
      @children = yield(self)
      @superclass, @body = children
    end
    
    def infer(typer)
      unless resolved?
        superclass = Duby::AST::type(@superclass.name) if @superclass
        @inferred_type ||= typer.define_type(name, superclass, @interfaces) do
          if body
            body.infer(typer)
          else
            typer.no_type
          end
        end
        @inferred_type ? resolved! : typer.defer(self)
      end

      @inferred_type
    end
    
    def implements(*types)
      raise ArgumentError if types.any? {|x| x.nil?}
      @interfaces.concat types
    end
  end

  class InterfaceDeclaration < ClassDefinition
    attr_accessor :superclass, :body, :interfaces
        
    def initialize(parent, line_number, name)
      super(parent, line_number, name) {|p| }
      @interfaces = []
      @name = name
      @children = yield(self)
      @interfaces, @body = children
    end
  end

  class FieldDeclaration < Node
    include Named
    include ClassScoped
    include Typed

    def initialize(parent, line_number, name)
      super(parent, line_number, yield(self))
      @name = name
      @type = children[0]
    end

    def infer(typer)
      unless resolved?
        resolved!
        @inferred_type = typer.known_types[type]
        if @inferred_type
          resolved!
          typer.learn_field_type(scope, name, @inferred_type)
        else
          typer.defer(self)
        end
      end
      @inferred_type
    end
  end
      
  class FieldAssignment < Node
    include Named
    include Valued
    include ClassScoped
        
    def initialize(parent, line_number, name)
      super(parent, line_number, yield(self))
      @value = children[0]
      @name = name
    end

    def infer(typer)
      unless resolved?
        @inferred_type = typer.learn_field_type(scope, name, value.infer(typer))

        @inferred_type ? resolved! : typer.defer(self)
      end

      @inferred_type
    end
  end
      
  class Field < Node
    include Named
    include ClassScoped
    
    def initialize(parent, line_number, name)
      super(parent, line_number)
      @name = name
    end

    def infer(typer)
      unless resolved?
        @inferred_type = typer.field_type(scope, name)

        @inferred_type ? resolved! : typer.defer(self)
      end

      @inferred_type
    end
  end
end