

export EuclideanVectorState, DiscreteState, ACEConfig



@doc raw"""
`struct EuclideanVectorState` : a $\mathbb{R}^3$-vector, which transforms under
the rotation group as
```math
g_Q \cdot {\bm r} = Q {\bm r}.
```
It typically defines a position or a force.
"""
struct EuclideanVectorState{T} <: AbstractContinuousState
   rr::SVector{3, T}
   label::String
end

EuclideanVectorState(rr::SVector{3}) = EuclideanVectorState(rr, "𝒓")
EuclideanVectorState{T}(label::String = "𝒓") where {T} = EuclideanVectorState(zero(SVector{3, T}), label)
EuclideanVectorState(label::String = "𝒓") = EuclideanVectorState(zero(SVector{3, Float64}), label)

Base.length(X::EuclideanVectorState) = 3

Base.show(io::IO, s::EuclideanVectorState) = print(io, "$(s.label)$(s.rr)")

import Base: *, -, +
*(A::Union{Number, AbstractMatrix}, X::EuclideanVectorState) =
      EuclideanVectorState(A * X.rr, X.label)
-(X::T) where {T <: EuclideanVectorState} = T( -X.rr, X.label)
+(X1::T, X2::T) where {T <: EuclideanVectorState} =
      T(X1.rr + X2.rr, X1.label)
+(X1::T, u::SVector{3}) where {T <: EuclideanVectorState} =
      T(X1.rr + u, X1.label)

@doc raw"""
`struct DiscreteState` : a state ``\mu`` specified by a discrete number of
possible values, e.g. ranging through ``\mathbb{Z}`` or ``\mathbb{Z}_p``.
Discrete states cannot possibly have a non-trivial transformation under
a continuoue group action, hence it is assumed to be invariant, i.e.,
```math
g_Q \cdot \mu = \mu
```
"""
struct DiscreteState{T, SYM} <: AbstractDiscreteState
   val::T
   _valsym::Val{SYM}
end

DiscreteState(sym::Symbol) = DiscreteState(0, Val(sym))
DiscreteState{T, SYM}(val::T) where {T, SYM} = DiscreteState(val, Val{SYM}())

Base.show(io::IO, s::DiscreteState{T, SYM}) where {T, SYM} =
         print(io, "$(SYM)[$(s.val)]")

Base.getproperty(s::DiscreteState{T, SYM}, sym) where {T, SYM} =
      sym == SYM ? getfield(s, :val) : getfield(s, sym)




struct ACEConfig{STT} <: AbstractConfiguration
   Xs::Vector{STT}   # list of states
end

# --- iterator to go through all states in an abstract configuration assuming
#     that the states are stored in cfg.Xs

Base.iterate(cfg::AbstractConfiguration) =
   length(cfg.Xs) == 0 ? nothing : (cfg.Xs[1], 1)

Base.iterate(cfg::AbstractConfiguration, i::Integer) =
   length(cfg.Xs) == i ? nothing : (cfg.Xs[i+1], i+1)

Base.length(cfg::AbstractConfiguration) = length(cfg.Xs)
