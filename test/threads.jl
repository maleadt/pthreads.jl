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

@testset "cancel" begin
    c = Channel()
    thread = pthread() do
        sleep(3)
        put!(c, 42)
    end
    @test isempty(c)
    sleep(1)  # give the thread a chance to finish compiling
    cancel(thread)
    sleep(2)
    @test isempty(c)
    @test_throws InterruptException wait(thread)
end

@testset "bug: pthread_exit(C_NULL) causes segfault on macOS" begin
    wait(pthread() do
        return
    end)
    GC.gc(true)
end

@testset "bug: leaving the GC enabled across pthread_testcancel causes segfault on macOS" begin
    let thread = pthread() do
            sleep(1)
        end
        cancel(thread)
        @test_throws InterruptException wait(thread)
    end
    wait(pthread() do
        return
    end)
    GC.gc(true)
end
