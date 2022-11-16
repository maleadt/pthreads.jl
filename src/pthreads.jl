module pthreads

function pthread_error(op, errno)
    # pthreads doesn't set errno internally
    error("$op: $(Libc.strerror(errno))")
end

is_debugbuild() = ccall(:jl_is_debugbuild, Cint, ()) == 0
if Sys.iswindows()
    using pthread_win32_jll
    const libpthread = pthread_win32_jll.pthread
else    # assume libjulia was linked against libpthread
    const libpthread = is_debugbuild() ? "libjulia-debug" : "libjulia"
end

include("threads.jl")

end # module pthreads
