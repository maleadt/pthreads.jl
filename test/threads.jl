# NOTE: using channels to ensure complex (blocking) interactions with the event loop

@testset "pthread(f, args)" begin
    c = Channel()
    function foo(arg)
        push!(c, arg)
        return
    end
    thread = pthread(foo, 42)
    @test take!(c) == 42
    wait(thread)
end

@testset "pthread() do ... end" begin
    c = Channel()
    thread = pthread() do
        put!(c, 42)
    end
    @test take!(c) == 42
    wait(thread)
end

@testset "detach" begin
    c = Channel()
    thread = pthread() do
        put!(c, 42)
    end
    detach(thread)
    @test take!(c) == 42
    @test_throws ErrorException wait(thread)
end

@testset "kill" begin
    c = Channel()
    thread = pthread() do
        sleep(0.1)
        put!(c, 42)
    end
    @test isempty(c)
    kill(thread)
    sleep(0.2)
    @test_broken isempty(c)     # Julia seems to ignore the signal...
end

@testset "cancel" begin
    c = Channel()
    thread = pthread() do
        sleep(0.1)
        put!(c, 42)
    end
    @test isempty(c)
    pthreads.cancel(thread)
    sleep(0.2)
    @test isempty(c)
end