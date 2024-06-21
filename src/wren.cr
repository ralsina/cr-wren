require "./api.cr"
require "uuid"

# A high-level, ergonomic wrapper for the Wren language
module Wren
  VERSION = "0.1.0"

  # High level interface to Wren
  class VM
    @config : API::WrenConfiguration
    @vm : API::WrenVM

    def self.get_func(x)
      @@functions[x]
    end

    @@vms = {} of String => VM

    def self.get_vm(vm)
      @@vms[vm]
    end

    def initialize(id : String)
      # Create configuration and set it to reasonable values
      @config = API::WrenConfiguration.new
      API.wrenInitConfiguration(pointerof(@config))

      # Called by `System.print` in Wren
      @config.writeFn = ->(_vm : API::WrenVM, text : LibC::Char*) : Nil { puts String.new(text) }
      # Called by Wren when there are errors
      @config.errorFn = ->(_vm : API::WrenVM, type : API::WrenErrorType, _module : LibC::Char*, line : LibC::Int32T, msg : LibC::Char*) : Nil {
        msg = String.new(msg)
        _module = String.new(_module) if _module
        case type
        when API::WrenErrorType::WREN_ERROR_COMPILE
          puts "[#{_module} line #{line}] [Error] #{msg}"
        when API::WrenErrorType::WREN_ERROR_STACK_TRACE
          puts "[#{_module} line #{line}] #{msg}"
        when API::WrenErrorType::WREN_ERROR_RUNTIME
          puts "[Runtime Error] #{msg}"
        end
      }

      # Lookup wrapped functions and return them. This function is called by the
      # Wren interpreter to find what to call when a foreign function is invoked
      # See: https://wren.io/embedding/calling-c-from-wren.html
      @config.bindForeignMethodFn = ->(_vm : API::WrenVM, mod : LibC::Char*, obj : LibC::Char*, _is_static : Bool, signature : LibC::Char*) : API::WrenForeignMethodFn {
        name, args = String.new(signature).split("(", 2)
        num_args = args.count("_")
        key = "#{String.new(mod)}::#{String.new(obj)}::#{name}::#{num_args}"
        VM.get_func(key)
      }

      # Initialize VM
      @vm = API.wrenNewVM(pointerof(@config))

      # Register
      @id = id
      @@vms[@id] = self
    end

    # Free resources allocated by Wren
    def finalize
      API.wrenFreeVM(@vm)
    end

    def _handle_interpret_result(result : API::WrenInterpretResult)
      case result
      when API::WrenInterpretResult::WREN_RESULT_COMPILE_ERROR
        raise "Compile error"
      when API::WrenInterpretResult::WREN_RESULT_RUNTIME_ERROR
        raise "Runtime error"
        # WREN_RESULT_SUCCESS
      end
    end

    # Flatten arrays in the specific way _set_slots wants
    def _flatten(args : Array(Value))
      flat_args = [] of Value
      args.each { |a|
        case a
        when Array
          flat_args += [a]
          flat_args += a
        else
          flat_args << a
        end
      }
      flat_args
    end

    # Sets slot `n` to value `val`
    def _set_slot(n : Int32, val : Value)
      _set_slots(n, [val])
    end

    # Sets all `args` into slots starting with `slot`
    def _set_slots(slot : Int32, args : Array(Value))
      # Flatten the array (no nested arrays yet)
      flat_args = _flatten(args)

      API.wrenEnsureSlots(@vm, slot + flat_args.size)

      flat_args.each_index { |i|
        a = flat_args[i]
        case a
        when Number
          API.wrenSetSlotDouble(@vm, slot + i, Float64.new(a))
        when Bool
          API.wrenSetSlotBool(@vm, slot + i, a)
        when Nil
          API.wrenSetSlotNull(@vm, slot + i)
        when String
          API.wrenSetSlotString(@vm, slot + i, a)
        when Array
          API.wrenSetSlotNewList(@vm, slot + i)
          (0...a.size).each { |j|
            API.wrenInsertInList(@vm, slot + i, -1, slot + i + j)
          }
        end
      }
    end

    # Get value from `slot`
    def _get_slot(slot : Int32)
      t = API.wrenGetSlotType(@vm, slot)
      case t
      when API::WrenType::WREN_TYPE_BOOL
        API.wrenGetSlotBool(@vm, slot)
      when API::WrenType::WREN_TYPE_NUM
        API.wrenGetSlotDouble(@vm, slot)
      when API::WrenType::WREN_TYPE_FOREIGN
        raise "Unimplemented FOREIGN type in getSlot"
      when API::WrenType::WREN_TYPE_LIST
        raise "Unimplemented LIST type in getSlot"
      when API::WrenType::WREN_TYPE_MAP
        raise "Unimplemented MAP type in getSlot"
      when API::WrenType::WREN_TYPE_NULL
        nil
      when API::WrenType::WREN_TYPE_STRING
        String.new(API.wrenGetSlotString(@vm, slot))
      end
    end

    # Get `count` slots starting with `start`
    def _get_slots(start : Int32, count : Int32)
      (start...start + count).map { |i| _get_slot(i) }
    end

    # Runs source, a string of Wren source code in a new fiber
    # in the vm, in the context of resolved module mod.
    # Raises exceptions in case of compile or runtime errors
    def interpret(mod : String, source : String)
      result = API.wrenInterpret(@vm, mod, source)
      _handle_interpret_result(result)
    end

    alias Atom = Float64 | Int64 | Int32 | Bool | String | Nil
    alias Value = Atom | Array(Atom)

    # Call a method in a Wren object, passing values as needed
    def call(mod : String, obj : String, method : String, args : Array(Value) = [] of Value)
      # Save enough slots, assume for now a flat array of args
      API.wrenEnsureSlots(@vm, args.size + 1)

      # Lookup the object in the module and put into slot 0
      API.wrenGetVariable(@vm, mod, obj, 0)
      # Fetch it and keep the handle to te object
      # TODO: cache these in a LRU
      obj = API.wrenGetSlotHandle(@vm, 0)

      # Create method call handle
      # TODO: Create a LRU cache of these
      sig = %(#{(["_"]*args.size).join(",")})
      method = API.wrenMakeCallHandle(
        @vm,
        %(#{method}(#{sig}))
      )

      # Setup everything in the slots
      API.wrenSetSlotHandle(@vm, 0, obj)
      _set_slots(1, args)

      # Perform the actual call, handle errors
      result = API.wrenCall(@vm, method)
      _handle_interpret_result(result)

      # Return return value
      _get_slot(0)
    end

    alias CallbackFunction = Proc(API::WrenVM, Nil)

    @@functions = {} of String => CallbackFunction

    def register_function(mod : String, obj : String, name : String, cb : {CallbackFunction, Int32})
      key = "#{mod}::#{obj}::#{name}::#{cb[1]}"
      @@functions[key] = cb[0]
    end

    # Wraps any proc with any number of arguments into a `CallbackFunction`
    # so it can be registered with the Wren interpreter using
    # `#register_function()`
    #
    # The first argument is the `Wren::VM.@id` for the VM where this function
    # will be used. This is sort of ugly but I have found no workaround.
    #
    # Arguments should have simple types like `Float64` or `String` and
    # they are casted using `as()` so if the actual argument passed from
    # Wren is the wrong type it *will* raise an exception.
    #
    # You can register multiple functions for the same name if their arity
    # is different.
    #
    # FIXME: since Crystal is polymorphic by type+arity and Wren is only
    # polymorphic by arity, so maybe support multiple functions of the
    # same arity wrapped together and dispatch to the one that matches
    # signature of the received arguments?
    macro wrap(vm_id, proc)
      {->(_vm : API::WrenVM) {
        # Define proc that does the inner work
        inner = {{proc.id}}

        # Get VM, then get right number of args from slots
        vm = Wren::VM.get_vm {{vm_id}}
        args = vm._get_slots(1, inner.arity)

        # Calculate result by calling inner with all the arguments
        # forcibly casted to expected signature
        result = inner.call(
          {% for t, i in proc.args %}
            args[{{i}}].as({{ t.restriction }}),
          {% end %}
        )

        # Send result via slots
        vm._set_slot(0, result)
      }, {{proc.args.size}}}
    end
  end
end

id = "myvm"

vm = Wren::VM.new id

# Test for simple interpret usage and writeFn
vm.interpret "main", "System.print(\"Hello World!\")"

# Test for calling from Crystal into Wren and getting values back
vm.interpret "main", %(
  var add = Fn.new { |a,b|
    return a+b
  }
)

puts vm.call("main", "add", "call", [1, 2])     # => 3.0
puts vm.call("main", "add", "call", ["1", "2"]) # => "12"

# Fails with a runtime error even when the equivalent Wren code works
# puts vm.call("main", "add", "call", [[1, 2], [3, 4]]) # => [1,2,3,4]

# Test calling functions from Wren to Crystal

# Register a simple proc to add floats
vm.register_function(
  "main", "Math", "add",
  Wren::VM.wrap("myvm", ->(a : Float64, b : Float64) : Float64 {
    a + b
  })
)

# Register a proc to add 3 floats. We can register the same function more than
# once with different arity
vm.register_function(
  "main", "Math", "add",
  Wren::VM.wrap("myvm", ->(a : Float64, b : Float64, c : Float64) : Float64 {
    a + b + c
  })
)

# Register it in the Wren side as foreign, use it.
vm.interpret "main", %(
  class Math {
    foreign static add(a,b)
    foreign static add(a,b,c)
  }
  System.print("2+3.5=")
  System.print(Math.add(2,3.5))
  System.print("1+2+3=")
  System.print(Math.add(1,2,3))
) # 2+3.5=5.5  1+2+3=6
