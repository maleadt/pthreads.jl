using Test, pthreads

@testset "pthreads" begin

@testset "threads" begin
include("threads.jl")
end

end
