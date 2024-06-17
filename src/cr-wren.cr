@[Link(ldflags: "-lwren")]
lib Wren
  alias WrenReallocateFn = Void*
  alias WrenResolveModuleFn = Void*
  alias WrenLoadModuleFn = Void*
  alias WrenBindForeignMethodFn = Void*
  alias WrenBindForeignClassFn = Void*
  alias WrenWriteFn = Proc(WrenVM, LibC::Char*, Nil)
  alias WrenErrorFn = Void*

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

  enum WrenInterpretResult
    WREN_RESULT_SUCCESS
    WREN_RESULT_COMPILE_ERROR
    WREN_RESULT_RUNTIME_ERROR
  end

  fun wrenInterpret(WrenVM, module : LibC::Char*, script : LibC::Char*) : WrenInterpretResult
end

module Cr::Wren
  VERSION = "0.1.0" # TODO: Put your code here
end

config = Wren::WrenConfiguration.new
print = ->(_vm : Wren::WrenVM, text : LibC::Char*) : Nil {puts String.new(text)}

Wren.wrenInitConfiguration(pointerof(config))
config.writeFn = print

vm = Wren.wrenNewVM(pointerof(config))
result = Wren.wrenInterpret(vm, "main", "System.print(\"Hello, World!\")")
