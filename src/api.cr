# A wrapper for the Wren language API
@[Link(ldflags: "-lwren")]
lib API
  alias WrenReallocateFn = Void*
  alias WrenResolveModuleFn = Void*
  alias WrenLoadModuleFn = Void*
  alias WrenForeignMethodFn = Proc(WrenVM, Nil)
  alias WrenBindForeignMethodFn = Proc(WrenVM, LibC::Char*, LibC::Char*, Bool, LibC::Char*, WrenForeignMethodFn)
  alias WrenBindForeignClassFn = Void*
  alias WrenWriteFn = Proc(WrenVM, LibC::Char*, Nil)
  alias WrenHandle = Void*

  # Low level Wren types
  enum WrenType
    WREN_TYPE_BOOL
    WREN_TYPE_NUM
    WREN_TYPE_FOREIGN
    WREN_TYPE_LIST
    WREN_TYPE_MAP
    WREN_TYPE_NULL
    WREN_TYPE_STRING
    # The object is of a type that isn't accessible by the C API.
    WREN_TYPE_UNKNOWN
  end

  # Types of Wren Errors
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
  fun wrenSetUserData(WrenVM, data : LibC::Char*)
  fun wrenGetUserData(WrenVM) : LibC::Char*

  # Errors returned by interpreter
  enum WrenInterpretResult
    WREN_RESULT_SUCCESS
    WREN_RESULT_COMPILE_ERROR
    WREN_RESULT_RUNTIME_ERROR
  end

  fun wrenInterpret(vm : WrenVM, module : LibC::Char*, script : LibC::Char*) : WrenInterpretResult

  # Slot related functions
  fun wrenEnsureSlots(vm : WrenVM, count : UInt32)
  fun wrenGetSlotType(vm : WrenVM, count : UInt32) : WrenType
  fun wrenGetSlotHandle(vm : WrenVM, slot : UInt32) : WrenHandle
  fun wrenSetSlotHandle(vm : WrenVM, slot : UInt32, handle : WrenHandle)
  fun wrenSetSlotDouble(vm : WrenVM, slot : UInt32, value : Float64)
  fun wrenGetSlotDouble(vm : WrenVM, slot : UInt32) : Float64
  fun wrenSetSlotBool(vm : WrenVM, slot : UInt32, value : Bool)
  fun wrenGetSlotBool(vm : WrenVM, slot : UInt32) : Bool
  fun wrenSetSlotNull(vm : WrenVM, slot : UInt32)
  fun wrenSetSlotString(vm : WrenVM, slot : UInt32, value : LibC::Char*)
  fun wrenGetSlotString(vm : WrenVM, slot : UInt32) : LibC::Char*
  fun wrenSetSlotNewList(vm : WrenVM, slot : UInt32)
  fun wrenInsertInList(vm : WrenVM, slot : UInt32, index : UInt32, elemSlot : UInt32)

  fun wrenCall(vm : WrenVM, method : WrenHandle) : WrenInterpretResult
  fun wrenMakeCallHandle(vm : WrenVM, signature : LibC::Char*) : WrenHandle
  fun wrenGetVariable(vm : WrenVM, mod : LibC::Char*, obj : LibC::Char*, slot : Int32)
end
