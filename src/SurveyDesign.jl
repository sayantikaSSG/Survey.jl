# Helper function for nice printing
function print_short(x)
    # write floats in short form
    if isa(x[1], Float64)
        x = round.(x, sigdigits=3)
    end
    # print short vectors or single values as they are, compress otherwise
    if length(x) < 3
        print(x)
    else
        print(x[1], ", ", x[2], ", ", x[3], " ... ", last(x))
    end
end

"""
Supertype for every survey design type: `SimpleRandomSample`, `ClusterSample`
and `StratifiedSample`.

The data to a survey constructor is modified. To avoid this pass a copy of the data
instead of the original.
"""
abstract type AbstractSurveyDesign end
"""
    SimpleRandomSample <: AbstractSurveyDesign

Survey design sampled by simple random sampling.

The population size is equal to the sample size unless `popsize` is explicitly provided.
"""
struct SimpleRandomSample <: AbstractSurveyDesign
    data::AbstractDataFrame
    sampsize::UInt
    popsize::Union{UInt,Nothing}
    sampfraction::Real
    fpc::Real
    ignorefpc::Bool
    function SimpleRandomSample(data::AbstractDataFrame;
                                popsize = nothing,
                                sampsize = nrow(data),
                                weights = ones(nrow(data)), # Check the defaults
                                probs = nothing,
                                ignorefpc = true
                                )
        if isa(weights, Symbol)
            weights = data[!, weights]
        end
        # set population size if it is not given; `weights` and `sampsize` must be given
        if isnothing(popsize)
            if typeof(weights) <: Vector{<:Real}
                if !all(y -> y == first(weights), weights) # SRS by definition is equi-weighted
                    error("Simple Random Sample must be equi-weighted. Different sampling weights detected in vectors")
                end
            elseif isa(weights, Symbol)
                weights = data[!, weights]
                if !all(y -> y == first(weights), weights) # SRS by definition is equi-weighted
                    error("Simple Random Sample must be equi-weighted. Different sampling weights detected in vectors")
                end
            elseif typeof(probs) <: Vector{<:Real}
                if !all(y -> y == first(probs), probs) # SRS by definition is equi-weighted
                    error("Simple Random Sample must be equi-weighted. Different sampling probabilities detected in vector")
                end
                weights = 1 ./ probs
            elseif isa(probs, Symbol)
                probs = data[!, probs]
                if !all(y -> y == first(probs), probs) # SRS by definition is equi-weighted
                    error("Simple Random Sample must be equi-weighted. Different sampling probabilities detected in vector")
                end
                weights = 1 ./ probs
            end
            # If all weights are equal then estimate
            equal_weight = first(weights)
            popsize = round(sampsize .* equal_weight) |> UInt
        elseif typeof(popsize) <: Vector{<:Real}
            if !all(y -> y == first(popsize), popsize) # SRS by definition is equi-weighted
                error("Simple Random Sample must be equi-weighted. Different sampling weights detected in vectors")
            end
            weights = popsize ./ sampsize
            popsize = first(popsize) |> UInt
        else
            error("If popsize not given then either sampling weights or sampling probabilities must be given")
        end
        # set sampling fraction
        sampfraction = sampsize ./ popsize
        # set fpc
        fpc = ignorefpc ? 1 : 1 .- (sampsize ./ popsize)
        # Add columns for weights and probs in data -- Check if really needed to add them as columns
        if !isnothing(probs)
            # add probability weights column to `data`
            data[!, :probs] = probs
            # add frequency weights column to `data`
            data[!, :weights] = 1 ./ data[!, :probs]
        else # else weights were specified
            # add frequency weights column to `data`
            data[!, :weights] = weights
            # add probability weights column to `data`
            data[!, :probs] = 1 ./ data[!, :weights]
        end
        new(data, sampsize, popsize, sampfraction, fpc, ignorefpc)
    end
end

# `show` method for printing information about a `SimpleRandomSample` after construction
function Base.show(io::IO, ::MIME"text/plain", design::SimpleRandomSample)
    printstyled("Simple Random Sample:\n"; bold=true)
    printstyled("data: "; bold=true)
    print(size(design.data, 1), "x", size(design.data, 2), " DataFrame")
    printstyled("\nweights: "; bold=true)
    print_short(design.data.weights)
    printstyled("\nprobs: "; bold=true)
    print_short(design.data.probs)
    printstyled("\nfpc: "; bold=true)
    print_short(design.fpc)
    printstyled("\npopsize: "; bold=true)
    print_short(design.popsize)
    printstyled("\nsampsize: "; bold=true)
    print_short(design.sampsize)
    printstyled("\nsampfraction: "; bold=true)
    print_short(design.sampfraction)
    printstyled("\nignorefpc: "; bold=true)
    print(design.ignorefpc)
end

"""
    StratifiedSample <: AbstractSurveyDesign

Survey design sampled by stratification.
"""
struct StratifiedSample <: AbstractSurveyDesign
    data::DataFrame
    sampsize::UInt
    popsize::Union{UInt,Nothing}
    sampfraction::Real
    fpc::Real
    nofpc::Bool
    function StratifiedSample(data::DataFrame, strata::AbstractVector; weights=ones(nrow(data)), probs=1 ./ weights)
        # add frequency weights, probability weights and sample size columns
        data[!, :weights] = weights
        data[!, :probs] = probs
        # TODO: change `sampsize` and `popsize`
        data[!, :popsize] = repeat([nrow(data)], nrow(data))
        data[!, :sampsize] = repeat([nrow(data)], nrow(data))
        data[!, :strata] = strata

        new(data)
    end
end

# `show` method for printing information about a `StratifiedSample` after construction
function Base.show(io::IO, design::StratifiedSample)
    printstyled("Stratified Sample:\n"; bold=true)
    printstyled("data: "; bold=true)
    print(size(design.data, 1), "x", size(design.data, 2), " DataFrame")
    printstyled("\nweights: "; bold=true)
    print_short(design.data.weights)
    printstyled("\nprobs: "; bold=true)
    print_short(design.data.probs)
    printstyled("\nstrata: "; bold=true)
    print_short(design.data.strata)
    printstyled("\nfpc: "; bold=true)
    print_short(design.fpc)
    printstyled("\n    popsize: "; bold=true)
    print(design.popsize)
    printstyled("\n    sampsize: "; bold=true)
    print(design.sampsize)
end

"""
    ClusterSample <: AbstractSurveyDesign

Survey design sampled by clustering.
"""
struct ClusterSample <: AbstractSurveyDesign
    data::DataFrame
end

# `show` method for printing information about a `ClusterSample` after construction
function Base.show(io::IO, design::ClusterSample)
    printstyled("Cluster Sample:\n"; bold=true)
    printstyled("data: "; bold=true)
    print(size(design.data, 1), "x", size(design.data, 2), " DataFrame")
    printstyled("\nweights: "; bold=true)
    print_short(design.data.weights)
    printstyled("\nprobs: "; bold=true)
    print_short(design.data.probs)
    printstyled("\nfpc: "; bold=true)
    print_short(design.fpc)
    printstyled("\n    popsize: "; bold=true)
    print(design.popsize)
    printstyled("\n    sampsize: "; bold=true)
    print(design.sampsize)
end
