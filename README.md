# pthreads.jl

*POSIX Threads support in Julia*

This package is a proof-of-concept showing how to create and manage POSIX Threads from
Julia. It is only supported on Julia 1.9 and above.

## Quick start

```julia
julia> using pthreads

julia> thread = pthread() do
           println("Hello, world!")
           return 42
       end;
Hello, world!

julia> # wait for the thread in order to access its return value
       wait(thread)
42
```
