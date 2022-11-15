module pthreads

function pthread_error(op, errno)
    # pthreads doesn't set errno internally
    error("$op: $(Libc.strerror(errno))")
end

include("threads.jl")

end # module pthreads
