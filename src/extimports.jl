


# -----------------------------------------------------------------------------
# modules external to our own eco-system, rigorously separate using and import

using Parameters: @with_kw

using Random: shuffle

import Base: ==, length, kron, filter

# for some reason it seems we need to export this to be used outside?!?!

using LinearAlgebra: norm, dot, mul!, I

using StaticArrays
