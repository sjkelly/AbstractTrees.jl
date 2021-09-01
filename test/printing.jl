# Test print_tree()


# count(pattern::String, string::String) and equivalent findall() method not
# present in Julia 0.7
function count_matches(pattern::AbstractString, string::AbstractString)
    c = 0
    next = 1

    while true
        match = findnext(pattern, string, next)
        if match === nothing
            return c
        else
            c += 1
            next = match.stop + 1
        end
    end
end


# Node type that wraps an integer value `n` and has two children with value `n + 1`.
# Resulting tree has infinite height.
abstract type AbstractNumTree; end
struct Num <: AbstractNumTree
    n::Int
end
Base.show(io::IO, x::AbstractNumTree) = print(io, x.n)
AbstractTrees.children(x::Num) = (Num(x.n+1), Num(x.n+1))


struct SingleChildInfiniteDepth end
AbstractTrees.children(::SingleChildInfiniteDepth) = (SingleChildInfiniteDepth(),)


# Wrapper around a collection which does not define getindex() or keys()
struct Unindexable{C}
    col::C

    Unindexable(col) = new{typeof(col)}(col)
end

Base.eltype(::Type{Unindexable{C}}) where C = eltype(C)
Base.length(u::Unindexable) = length(u.col)
Base.iterate(u::Unindexable, args...) = iterate(u.col, args...)


# Wrapper around a node which wraps children in UnIndexable
struct UnindexableChildren{N}
    node::N
end

AbstractTrees.children(u::UnindexableChildren) = Unindexable(children(u.node))
AbstractTrees.printnode(io::IO, u::UnindexableChildren) = AbstractTrees.printnode(io, u.node)


@testset "Truncation" begin

    # test that `print_tree(headnode, maxdepth)` truncates the output at right depth
    # julia > print_tree(Num(0), 3)
    # 0
    # ├─ 1
    # │  ├─ 2
    # │  │  ├─ 3
    # │  │  └─ 3
    # │  └─ 2
    # │     ├─ 3
    # │     └─ 3
    # └─ 1
    #    ├─ 2
    #    │  ├─ 3
    #    │  └─ 3
    #    └─ 2
    #       ├─ 3
    #       └─ 3
    #

    truncation_str = AbstractTrees.DEFAULT_CHARSET.trunc

    for maxdepth in [3,5,8]
        ptxt = repr_tree(Num(0), maxdepth=maxdepth)

        # Check that we see depth #s the expected number of times
        @test count_matches(string(maxdepth-1), ptxt) == 2^(maxdepth-1)
        @test count_matches(string(maxdepth), ptxt) == 2^maxdepth
        @test count_matches(string(maxdepth+1), ptxt) == 0

        # test that `print_tree(headnode)` prints truncation characters under each
        # node at the maximum depth
        lines = split(ptxt, '\n')
        for i in 1:length(lines)
            if occursin(string(maxdepth), lines[i])
                @test endswith(lines[i+1], truncation_str)
            end
        end
    end

    # test correct number of lines printed 1
    ptxt = repr_tree(SingleChildInfiniteDepth())
    numlines = sum([1 for c in split(ptxt, '\n') if ~isempty(strip(c))])
    @test numlines == 7 # 1 (head node) + 5 (default depth) + 1 (truncation char)

    # test correct number of lines printed 2
    ptxt = repr_tree(SingleChildInfiniteDepth(), maxdepth=3)
    numlines = sum([1 for c in split(ptxt, '\n') if ~isempty(strip(c))])
    @test numlines == 5 # 1 (head node) + 3 (depth) + 1 (truncation char)

    # test correct number of lines printed 3
    ptxt = repr_tree(SingleChildInfiniteDepth(), maxdepth=3, indicate_truncation=false)
    numlines = sum([1 for c in split(ptxt, '\n') if ~isempty(strip(c))])
    @test numlines == 4 # 1 (head node) + 3 (depth)
end


@testset "print_tree maxdepth as positional argument" begin
    tree = Num(0)

    @test_deprecated print_tree(devnull, tree, 3)
    @test_deprecated print_tree(AbstractTrees.printnode, devnull, tree, 3)

    buf = IOBuffer()

    for maxdepth in [3, 5, 8]
        @test_deprecated print_tree(buf, tree, maxdepth)
        str = String(take!(buf))
        truncate(buf, 0)

        @test str == repr_tree(tree, maxdepth=maxdepth)
    end
end


@testset "print_tree with non-indexable children" begin
    tree = Num(0)
    @test repr_tree(UnindexableChildren(tree), maxdepth=4) == repr_tree(tree, maxdepth=4)
end
