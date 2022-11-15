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

if !Sys.isapple()
    # on Darwin, cancellation seems asynchronous, and gets delivered on specific syscalls.
    # this results in the thread getting killed when we start compiling the `put!`...
    @testset "cancel" begin
        c = Channel()
        thread = pthread() do
            sleep(3)
            put!(c, 42)
        end
        @test isempty(c)
        sleep(1)  # give the thread a chance to finish compiling
        pthreads.cancel(thread)
        sleep(2)
        @test isempty(c)
        @test_throws InterruptException wait(thread)
    end
end
