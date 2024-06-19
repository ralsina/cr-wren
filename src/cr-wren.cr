# A higher-level, more ergonomic wrapper
module Wren
  VERSION = "0.1.0"

  # A wrapper for the Wren language API
  @[Link(ldflags: "-lwren")]
  lib API
    alias WrenReallocateFn = Void*
    alias WrenResolveModuleFn = Void*
    alias WrenLoadModuleFn = Void*
    alias WrenBindForeignMethodFn = Void*
    alias WrenBindForeignClassFn = Void*
    alias WrenWriteFn = Proc(WrenVM, LibC::Char*, Nil)

    enum WrenErrorType
      WREN_ERROR_COMPILE
      WREN_ERROR_RUNTIME
      WREN_ERROR_STACK_TRACE
    end
    alias WrenErrorFn = Proc(WrenVM, WrenErrorType, LibC::Char*, LibC::Int32T, LibC::Char*, Nil)

    struct WrenConfiguration
      reallocateFn : WrenReallocateFn
      resolveModuleFn : WrenResolveModuleFn
      loadModuleFn : WrenLoadModuleFn
      bindForeignMethodFn : WrenBindForeignMethodFn
      bindForeignClassFn : WrenBindForeignClassFn
      writeFn : WrenWriteFn
      errorFn : WrenErrorFn
      initialHeapSize : LibC::SizeT
      minHeapSize : LibC::SizeT
      heapGrowthPercent : LibC::Int32T
      userData : Void*
    end

    fun wrenInitConfiguration(config : WrenConfiguration*) : Void

    type WrenVM = Void*
    fun wrenNewVM(config : WrenConfiguration*) : WrenVM
    fun wrenFreeVM(WrenVM)

    enum WrenInterpretResult
      WREN_RESULT_SUCCESS
      WREN_RESULT_COMPILE_ERROR
      WREN_RESULT_RUNTIME_ERROR
    end

    fun wrenInterpret(WrenVM, module : LibC::Char*, script : LibC::Char*) : WrenInterpretResult
  end

  class VM
    @config : API::WrenConfiguration
    @vm : API::WrenVM

    def initialize
      # Create configuration and set it to reasonable values
      @config = API::WrenConfiguration.new
      API.wrenInitConfiguration(pointerof(@config))

      # TODO: Make these configurable in a nice way
      @config.writeFn = ->(_vm : Wren::API::WrenVM, text : LibC::Char*) : Nil { puts String.new(text) }
      @config.errorFn = ->(_vm : Wren::API::WrenVM, type : Wren::API::WrenErrorType, _module : LibC::Char*, line : LibC::Int32T, message : LibC::Char*) : Nil {
        puts "Error: #{type} in module #{String.new(_module)} line: #{line}"
        puts "Message: #{String.new(message)}"
      }

      # Initialize VM
      @vm = Wren::API.wrenNewVM(pointerof(@config))
    end

    # Free resources allocated by Wren
    def finalize
      API.wrenFreeVM(@vm)
    end

    # Runs source, a string of Wren source code in a new fiber
    # in the vm, in the context of resolved module mod
    def interpret(mod : String, source : String)
      result = API.wrenInterpret(@vm, mod, source)
      case result
      when API::WrenInterpretResult::WREN_RESULT_COMPILE_ERROR
        raise "Compile error"
      when API::WrenInterpretResult::WREN_RESULT_RUNTIME_ERROR
        raise "Runtime error"
        # WREN_RESULT_SUCCESS
      end
    end
  end
end

vm = Wren::VM.new
vm.interpret "main", "System.print(\"Hello World!\")"
