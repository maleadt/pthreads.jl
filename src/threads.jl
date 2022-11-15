export pthread

# TODO: update for other platforms
struct pthread_t
    val::Culong
end

Base.:(==)(a::pthread_t, b::pthread_t) =
    ccall(:pthread_equal, Cint, (pthread_t, pthread_t), a, b) != 0

"""
    pthreads.threadid()

Get the thread id of the current thread. This is an opaque identifier, and can only be
compared against other pthread identifiers.
"""
function threadid()
    ccall(:pthread_self, pthread_t, ())
end

"""
    pthread(f, args...)
    pthread() do ... end

Create a new thread and execute `f(args...)` in it. Returns a `pthread` object.
You need to either `detach` or `wait` for the thread to finish.
"""
mutable struct pthread
    tid::pthread_t

    const f
    const args::Vector{Any}

    # output of the function
    # (stored here instead of passed to pthread_exit for simplicity of ownership)
    ret
    err
    bt

    pthread(tid, f, args) = new(tid, f, args)
end

Base.convert(::Type{pthread_t}, t::pthread) = t.tid

const pthread_dispatch_cb = Ref{Any}()
function pthread_dispatch(threadptr::Ptr{pthread})
    thread = Base.unsafe_pointer_to_objref(threadptr)
    try
        thread.ret = thread.f(thread.args...)
    catch err
        thread.err = err
        thread.bt = catch_backtrace()
    finally
        # normally we can rely on pthreads to call pthread_exit on return,
        # but on macOS that sets a non-null return code, so do it manually.
        ccall(:pthread_exit, Nothing, (Ptr{Nothing},), C_NULL)
    end
    return
end

function pthread(f, args...)
    if !isassigned(pthread_dispatch_cb)
        pthread_dispatch_cb[] = @cfunction(pthread_dispatch, Cvoid, (Ptr{pthread},))
    end
    thread = pthread(pthread_t(0), f, Any[args...])
    tid = Ref{pthread_t}()
    status = ccall(:pthread_create, Cint,
                   (Ptr{pthread_t}, Ptr{Nothing}, Ptr{Nothing}, Ref{pthread}),
                   tid, C_NULL, pthread_dispatch_cb[], thread)
    status == 0 || pthread_error("pthread_create", status)
    thread.tid = tid[]
    thread
end

if Sys.isapple()
    const PTHREAD_CANCELED = Ptr{Cvoid}(1)
elseif Sys.islinux()
    const PTHREAD_CANCELED = Ptr{Cvoid}(-1)
end

"""
    wait(thread::pthread)

Wait for the thread to finish and return the value returned by the thread, or throw the
exception thrown by the thread.
"""
function Base.wait(thread::pthread)
    # can't call pthread_join directly, because that may block the main thread
    # and cause a deadlock when other threads are waiting for the event loop.
    ret = Ref{Ptr{Cvoid}}(C_NULL)
    status = @threadcall(:pthread_join, Cint,
                         (pthread_t, Ptr{Ptr{Nothing}}),
                         thread, ret)
    status == 0 || pthread_error("pthread_join", status)

    if ret[] == PTHREAD_CANCELED
        throw(InterruptException())
    elseif isdefined(thread, :err)
        throw(thread.err)   # TODO: throw with backtrace (creating an exception stack)
    else
        return thread.ret
    end
end

"""
    detach(thread::pthread)

Detach the thread from the current process. The thread will continue to run, but you will
not need to `wait` for the thread to ensure its resources are cleaned up.
"""
function Base.detach(thread::pthread)
    status = ccall(:pthread_detach, Cint, (pthread_t,), thread)
    status == 0 || pthread_error("pthread_detach", status)
    return
end

"""
    kill(thread::pthread, [signum::Integer=SIGINT])

Send a signal to the thread. The default signal is `SIGINT`.
"""
function Base.kill(thread::pthread, signum=Base.SIGINT)
    status = ccall(:pthread_kill, Cint, (pthread_t, Cint), thread, signum)
    status == 0 || pthread_error("pthread_kill", status)
    # XXX: this doesn't seem to work; Julia seems to ignore the signal
    return
end

"""
    cancel(thread::pthread)

Forcibly cancel a thread.

!!! warning

    This function is dangerous, as it may result in a thread being canceled from an unsafe
    point, e.g., during compilation (where locks have been taken).
"""
function cancel(thread::pthread)
    # XXX: support cancellation points
    status = ccall(:pthread_cancel, Cint, (pthread_t,), thread)
    status == 0 || pthread_error("pthread_cancel", status)
    return
end
