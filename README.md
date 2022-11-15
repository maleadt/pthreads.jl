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

If you don't care about the results, you can detach the thread:

```julia
julia> using pthreads

julia> thread = pthread() do
           println("Off we go!")
           return
       end;
Off we go!

julia> detach(thread)
```

It's also possible to cancel running threads:

```julia
julia> thread = pthread() do
           println("This will take a while...")
           sleep(999)
       end;
This will take a while...

julia> cancel(thread)

julia> # wait for the thread in order to detect any exception
       wait(thread)
ERROR: InterruptException
```

Note that the ability to run foreign threads is a relatively recent addition to Julia,
and there may be bugs. Specifically, it is very likely that thread removal (either by
cancelling threads, or by threads just finishing) can lead to corrupt state in the Julia
scheduler, so it's recommended to be conservative with such operations.
