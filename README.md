# cr-wren

This is a binding to embed the [Wren language](https://wren.io/) into
Crystal and call Wren code from Crystal and viceversa.

## Why Wren

Wren is a small, fast, class-based, concurrent scripting language.

I like the syntax much better than Lua's or Javascript's and it's a
fairly powerful language with decent performance.

## Installation

This is a WIP, I may end up vendoring wren inside this project.

1. Install [wren](https://wren.io/) as a library in your system.

   * In Arch: `yay install wren`
   * In other systems: [Embedding instructions](https://wren.io/getting-started)html#embed-the-vm

2. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     cr-wren:
       github: ralsina/cr-wren
   ```

3. Run `shards install`

## Usage

This is a fully commented example:

```crystal
require "../src/wren.cr"  # Adjust as needed

vm = Wren::VM.new "myvm"

# We can just tell the VM to interpret (run) code
vm.interpret "main", "System.print(\"Hello World!\")"

# This defines a function in Wren
vm.interpret "main", %(
  var add = Fn.new { |a,b|
    return a+b
  }
)

# And we can call it from Crystal
puts vm.call("main", "add", "call", [1, 2])     # => 3.0
puts vm.call("main", "add", "call", ["1", "2"]) # => "12"

# This fails with a runtime error even when the equivalent Wren code works
# probably a bug somewhere
# puts vm.call("main", "add", "call", [[1, 2], [3, 4]]) # => [1,2,3,4]


# Register a Crystal proc to add floats into the Wren VM
vm.register_function(
  "main", "Math", "add",
  Wren::VM.wrap("myvm", ->(a : Float64, b : Float64) : Float64 {
    a + b
  })
)

# Register a proc to add 3 floats. We can register the same proc more than
# once with the same name and different arity
vm.register_function(
  "main", "Math", "add",
  Wren::VM.wrap("myvm", ->(a : Float64, b : Float64, c : Float64) : Float64 {
    a + b + c
  })
)

# We also need to declare it as "foreign" in Wren.
vm.interpret "main", %(
  class Math {
    foreign static add(a,b)
    foreign static add(a,b,c)
  }
)

# And we can call it on Wren, which will use the Crystal code
vm.interpret "main", %(
  System.print("2+3.5=")
  System.print(Math.add(2,3.5))
  System.print("1+2+3=")
  // We can pass a string as argument here because cr-wren will cast it to Float64
  System.print(Math.add("1",2,3))
) # 2+3.5=5.5  ¨1"+2+3=6
```

## Development

This is early code, not much here.

## Contributing

1. Fork it (<https://github.com/ralsina/cr-wren/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

* [Roberto Alsina](https://github.com/ralsina) - creator and maintainer
