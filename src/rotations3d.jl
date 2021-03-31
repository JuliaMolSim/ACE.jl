
# --------------------------------------------------------------------------
# ACE.jl: Julia implementation of the Atomic Cluster Expansion
# Copyright (c) 2019 Christoph Ortner <christophortner0@gmail.com>
# All rights reserved.
# --------------------------------------------------------------------------



module Rotations3D

using StaticArrays
using LinearAlgebra: norm, rank, svd, Diagonal
using ACE.SphericalHarmonics: index_y
using Combinatorics: permutations

export ClebschGordan, Rot3DCoeffs, ri_basis, rpi_basis, clebschgordan
# Extra export - for SphericalVector
export yvec_symm_basis


"""
`ClebschGordan: ` storing precomputed Clebsch-Gordan coefficients; see
`?clebschgordan` for the convention that is use.
"""
struct ClebschGordan{T}
	vals::Dict{Tuple{Int, Int, Int, Int, Int, Int}, T}
end

"""
`Rot3DCoeffs: ` storing recursively precomputed coefficients for a
rotation-invariant basis.
"""
struct Rot3DCoeffs{T}
   vals::Vector{Dict}
   cg::ClebschGordan{T}
end

#------------------------------------
# What I added
struct D_Index
	l::Int64
	μ::Int64
	m::Int64
end
#------------------------------------

# -----------------------------------
# iterating over an m collection
# -----------------------------------

_mvec(::CartesianIndex{0}) = SVector(Int(0))

_mvec(mpre::CartesianIndex) = SVector(Tuple(mpre)..., - sum(Tuple(mpre)))

struct MRange{N, T2}
   ll::SVector{N, Int}
   cartrg::T2
end

Base.length(mr::MRange) = sum(_->1, _mrange(mr.ll))

"""
Given an l-vector `ll` iterate over all combinations of `mm` vectors  of
the same length such that `sum(mm) == 0`
"""
_mrange(ll) = MRange(ll, Iterators.Stateful(
                     CartesianIndices(ntuple(i -> -ll[i]:ll[i], length(ll)-1))))

function Base.iterate(mr::MRange{1}, args...)
   if isempty(mr.cartrg)
      return nothing
   end
   while !isempty(mr.cartrg)
      popfirst!(mr.cartrg)
   end
   return SVector{1, Int}(0), nothing
end

function Base.iterate(mr::MRange, args...)
   while true
      if isempty(mr.cartrg)
         return nothing
      end
      mpre = popfirst!(mr.cartrg)
      if abs(sum(mpre.I)) <= mr.ll[end]
         return _mvec(mpre), nothing
      end
   end
   error("we should never be here")
end



# ----------------------------------------------------------------------
#     ClebschGordan code
# ----------------------------------------------------------------------


cg_conditions(j1,m1, j2,m2, J,M) =
	cg_l_condition(j1, j2, J)   &&
	cg_m_condition(m1, m2, M)   &&
	(abs(m1) <= j1) && (abs(m2) <= j2) && (abs(M) <= J)

cg_l_condition(j1, j2, J) = (abs(j1-j2) <= J <= j1 + j2)

cg_m_condition(m1, m2, M) = (M == m1 + m2)


"""
`clebschgordan(j1, m1, j2, m2, J, M, T=Float64)` :

A reference implementation of Clebsch-Gordon coefficients based on

https://hal.inria.fr/hal-01851097/document
Equation (4-6)

This heavily uses BigInt and BigFloat and should therefore not be employed
for performance critical tasks, but only precomputation.

The ordering of parameters corresponds to the following convention:
```
clebschgordan(j1, m1, j2, m2, J, M) = C_{j1m1j2m2}^{JM}
```
where
```
   D_{m1k1}^{l1} D_{m2k2}^{l2}}
	=
	∑_j  C_{l1m1l2m2}^{j(m1+m2)} C_{l1k1l2k2}^{j2(k1+k2)} D_{(m1+m2)(k1+k2)}^{j}
```
"""
function clebschgordan(j1, m1, j2, m2, J, M, T=Float64)
	if !cg_conditions(j1, m1, j2, m2, J, M)
		return zero(T)
	end

   N = (2*J+1) *
       factorial(big(j1+m1)) * factorial(big(j1-m1)) *
       factorial(big(j2+m2)) * factorial(big(j2-m2)) *
       factorial(big(J+M)) * factorial(big(J-M)) /
       factorial(big( j1+j2-J)) /
       factorial(big( j1-j2+J)) /
       factorial(big(-j1+j2+J)) /
       factorial(big(j1+j2+J+1))

   G = big(0)
   # 0 ≦ k ≦ j1+j2-J
   # 0 ≤ j1-m1-k ≤ j1-j2+J   <=>   j2-J-m1 ≤ k ≤ j1-m1
   # 0 ≤ j2+m2-k ≤ -j1+j2+J  <=>   j1-J+m2 ≤ k ≤ j2+m2
   lb = (0, j2-J-m1, j1-J+m2)
   ub = (j1+j2-J, j1-m1, j2+m2)
   for k in maximum(lb):minimum(ub)
      bk = big(k)
      G += (-1)^k *
           binomial(big( j1+j2-J), big(k)) *
           binomial(big( j1-j2+J), big(j1-m1-k)) *
           binomial(big(-j1+j2+J), big(j2+m2-k))
   end

   return T(sqrt(N) * G)
end


ClebschGordan(T=Float64) =
	ClebschGordan{T}(Dict{Tuple{Int,Int,Int,Int,Int,Int}, T}())

_cg_key(j1, m1, j2, m2, J, M) = (j1, m1, j2, m2, J, M)
	# Int.((index_y(j1,m1), index_y(j2,m2), index_y(J,M)))

function (cg::ClebschGordan{T})(j1, m1, j2, m2, J, M) where {T}
	if !cg_conditions(j1,m1, j2,m2, J,M)
		return zero(T)
	end
	key = _cg_key(j1, m1, j2, m2, J, M)
	if haskey(cg.vals, key)
		return cg.vals[key]
	end
	val = clebschgordan(j1, m1, j2, m2, J, M, T)
	cg.vals[key] = val
	return val
end


# ----------------------------------------------------------------------
#     Rot3DCoeffs code: generalized cg coefficients
#
#  Note: in this section kk is a tuple of m-values, it is not
#        related to the k index in the 1-p basis (or radial basis)
# ----------------------------------------------------------------------

dicttype(N::Integer) = dicttype(Val(N))

dicttype(::Val{N}) where {N} =
   Dict{Tuple{SVector{N,Int}, SVector{N,Int}, SVector{N,Int}}, Float64}

Rot3DCoeffs(T=Float64) = Rot3DCoeffs(Dict[], ClebschGordan(T))


function get_vals(A::Rot3DCoeffs, valN::Val{N}) where {N}
	if length(A.vals) < N
		for n = length(A.vals)+1:N
			push!(A.vals, dicttype(n)())
		end
	end
   return A.vals[N]::dicttype(valN)
end

_key(ll::StaticVector{N}, mm::StaticVector{N}, kk::StaticVector{N}) where {N} =
      (SVector{N, Int}(ll), SVector{N, Int}(mm), SVector{N, Int}(kk))

function (A::Rot3DCoeffs{T})(ll::StaticVector{N},
                             mm::StaticVector{N},
                             kk::StaticVector{N}) where {T, N}
   if       sum(mm) != 0 ||
            sum(kk) != 0 ||
            !all(abs.(mm) .<= ll) ||
            !all(abs.(kk) .<= ll)
      return T(0)
   end
   vals = get_vals(A, Val(N))  # this should infer the type!
   key = _key(ll, mm, kk)
   if haskey(vals, key)
      val  = vals[key]
   else
      val = _compute_val(A, key...)
      vals[key] = val
   end
   return val
end

# the recursion has two steps so we need to define the
# coupling coefficients for N = 1, 2
# TODO: actually this seems false; it is only one recursion step, and a bit
#       or reshuffling should allow us to get rid of the {N = 2} case.

function (A::Rot3DCoeffs{T})(ll::StaticVector{1},
                            mm::StaticVector{1},
                            kk::StaticVector{1}) where {T}
   if ll[1] == mm[1] == kk[1] == 0
      return T(1)
   else
      return T(0)
   end
end

function (A::Rot3DCoeffs{T})(ll::StaticVector{2},
                            mm::StaticVector{2},
                            kk::StaticVector{2}) where {T}
   if ll[1] != ll[2] || sum(mm) != 0 || sum(kk) != 0
      return T(0)
   else
      return T( 8 * pi^2 / (2*ll[1]+1) * (-1)^(mm[1]-kk[1]) )
   end
end

# next comes the recursion step for N ≧ 3

function _compute_val(A::Rot3DCoeffs{T}, ll::StaticVector{N},
                                        mm::StaticVector{N},
                                        kk::StaticVector{N}) where {T, N}
	val = T(0)
   llp = ll[1:N-2]
   mmp = mm[1:N-2]
   kkp = kk[1:N-2]
   for j = abs(ll[N-1]-ll[N]):(ll[N-1]+ll[N])
      if abs(kk[N-1]+kk[N]) > j || abs(mm[N-1]+mm[N]) > j
         continue
      end
		cgk = try
			A.cg(ll[N-1], kk[N-1], ll[N], kk[N], j, kk[N-1]+kk[N])
		catch
			@show (ll[N-1], kk[N-1], ll[N], kk[N], j, kk[N-1]+kk[N])
			T(0)
		end
		cgm = A.cg(ll[N-1], mm[N-1], ll[N], mm[N], j, mm[N-1]+mm[N])
		if cgk * cgm  != 0
			val += cgk * cgm * A( SVector(llp..., j),
								       SVector(mmp..., mm[N-1]+mm[N]),
								       SVector(kkp..., kk[N-1]+kk[N]) )
		end
   end
   return val
end

# ----------------------------------------------------------------------
#   construction of a possible set of generalised CG coefficient;
#   numerically via SVD
# ----------------------------------------------------------------------


function ri_basis(A::Rot3DCoeffs{T}, ll::SVector; ordered=false) where {T}
	CC = compute_Al(A, ll, Val(ordered))
	svdC = svd(CC)
	rk = rank(Diagonal(svdC.S))
	return svdC.U[:, 1:rk]'
end


# unordered
function compute_Al(A::Rot3DCoeffs{T}, ll::SVector, ::Val{false}) where {T}
	len = length(_mrange(ll))
	CC = zeros(T, len, len)
	for (im, mm) in enumerate(_mrange(ll)), (ik, kk) in enumerate(_mrange(ll))
		CC[ik, im] = A(ll, mm, kk)
	end
	return CC
end


# TODO: this could use some documentation
# ?? What is zz here?
rpi_basis(A::Rot3DCoeffs, zz, nn, ll) =
			rpi_basis(A, SVector(zz...), SVector(nn...), SVector(ll...))

# No matter what structure do zz/nn/ll have, turn them into SVector

function rpi_basis(A::Rot3DCoeffs, nn::SVector{N, TN}, ll::SVector{N, Int}) where {N, TN}
	Uri = ri_basis(A, ll)
	Mri = collect( _mrange(ll) )   # rows...
	G = _gramian(nn, ll, Uri, Mri)
    S = svd(G)
    rk = rank(G; rtol =  1e-7)
	Urpi = S.U[:, 1:rk]'
	return Diagonal(sqrt.(S.S[1:rk])) * Urpi * Uri, Mri
end


function _gramian(nn, ll, Uri, Mri)
   N = length(nn)
   nri = size(Uri, 1)
   @assert size(Uri, 1) == nri
   G = zeros(nri, nri)
   for σ in permutations(1:N)
      if (nn[σ] != nn) || (ll[σ] != ll); continue; end
      for (iU1, mm1) in enumerate(Mri), (iU2, mm2) in enumerate(Mri)
         if mm1[σ] == mm2
            for i1 = 1:nri, i2 = 1:nri
               G[i1, i2] += conj(Uri[i1, iU1]) * Uri[i2, iU2]
            end
         end
      end
   end
   return G
end

## Covariant construction for SphericalVector

# Equation (1.1) - forms the covariant matrix D(Q)(indices only)
function Rotation_D_matrix(φ::Sphericalvector)
	if φ._valL<0
		error("Orbital type shall be represented as a positive integer!")
	end
    D = Array{D_Index}(undef, 2 * φ._valL + 1, 2 * φ._valL + 1)
    for i = 1 : 2 * φ._valL + 1
        for j = 1 : 2 * φ._valL + 1
            D[i,j] = D_Index(φ._valL, i - 1 - φ._valL, j - 1 - φ._valL);
        end
    end
	return D
end

# Equation (1.2) - vector value coupling coefficients
function local_cou_coe(A::Rot3DCoeffs, ll::StaticVector{N}, mm::StaticVector{N},
					   kk::StaticVector{N}, φ::Sphericalvector, t::Int64) where {N}
	if t > 2φ._valL + 1
		error("Rotation D matrix has no such column!")
	end
	Z = zeros(Complex{Float64},2φ._valL + 1);
	D = Rotation_D_matrix(φ);
	Dt = D[:,t];
	μt = [Dt[i].μ for i in 1:2φ._valL+1];
	mt = [Dt[i].m for i in 1:2φ._valL+1];
	LL = SVector([ll;φ._valL]...);
	for i = 1 : 2φ._valL + 1
		MM = SVector([mm;mt[i]]...);
		KK = SVector([kk;μt[i]]...);
		Z[i] = A(LL, MM, KK);
	end
	return Z
end

# Equation (1.5) - possible set of mm w.r.t. vector k
function collect_m(ll::StaticVector{N}, k::T) where {N,T}
	d = length(k);
	A = CartesianIndices(ntuple(i -> -ll[i]:ll[i], length(ll)));
	B = Array{typeof(A[1].I)}(undef, 1, prod(size(A)))
	t = 0;
	for i in A
		if prod(sum(i.I) .+ k) == 0
			t = t + 1;
			B[t] = i.I;
		end
	end
	B = [SVector(i) for i in B[1:t]]
	return B
end

# Equation(1.7) & (1.6) respectively - gramian
function gramian(A::Rot3DCoeffs, ll::StaticVector{N}, φ::Sphericalvector, t::Int64) where{N}
	D = Rotation_D_matrix(φ);
	Dt = D[:,t];
	μt = [Dt[i].μ for i in 1:2φ._valL+1];
	mt = [Dt[i].m for i in 1:2φ._valL+1];
	m_list = collect_m(ll,mt);
	μ_list = collect_m(ll,μt);
	Z = [zeros(2φ._valL + 1) for i = 1:length(μ_list), j = 1:length(m_list)];
	for (im, mm) in enumerate(m_list), (iμ, μμ) in enumerate(μ_list)
		Z[iμ,im] = local_cou_coe(A, ll, mm, μμ, φ, t);
	end
	return Z' * Z, Z;
end

# Equation (1.8) - LI set w.r.t. t & ll (not for nn for now)
function rc_basis(A::Rot3DCoeffs, ll::StaticVector{N}, φ::Sphericalvector, t::Int64) where {N}
	G, C = gramian(A, ll, φ, t);
	D = Rotation_D_matrix(φ);
	Dt = D[:,t];
	μt = [Dt[i].μ for i in 1:2φ._valL+1];
	mt = [Dt[i].m for i in 1:2φ._valL+1];
	S = svd(G);
	rk = rank(G; rtol =  1e-8);
	μ_list = collect_m(ll,μt)
	Urcpi = [zeros(2φ._valL + 1) for i = 1:rk, j = 1:length(μ_list)];
	U = S.U[:, 1:rk];
	Sigma = S.S[1:rk]
	Urcpi = C * U * Diagonal(sqrt.(Sigma))^(-1);
	return Urcpi', μ_list
end

# Equation (1.10) - Collecting all t and sorting them in order
function rcpi_basis_all(A::Rot3DCoeffs, ll::StaticVector{N}, φ::Sphericalvector) where {N}
	Urcpi_all, μ_list = rc_basis(A, ll, φ, 1);
	if φ._valL ≠ 0
		for t = 2 : 2φ._valL+1
			Urcpi_all = [Urcpi_all; rc_basis(A, ll, φ, t)[1]];
		end
	end
	return Urcpi_all, μ_list
end

# Equation (1.12) - Gramian over nn
function Gramian(A::Rot3DCoeffs, nn::StaticVector{N}, ll::StaticVector{N}, φ::Sphericalvector) where {N}
	Uri, Mri = rcpi_basis_all(A, ll, φ);
#	m_list = collect_m(ll,mt)
	G = zeros(Complex{Float64}, size(Uri)[1], size(Uri)[1]);
	for σ in permutations(1:N)
       if (nn[σ] != nn) || (ll[σ] != ll); continue; end
       for (iU1, mm1) in enumerate(Mri), (iU2, mm2) in enumerate(Mri)
          if mm1[σ] == mm2
             for i1 = 1:size(Uri)[1]
				 for i2 = 1:size(Uri)[1]
                 	G[i1, i2] += Uri[i1, iU1] * Uri[i2, iU2]'
				end
             end
          end
       end
    end
    return G, Uri
end

"""
'Rcpi_basis_final' function is aiming to take the place of 'yvec_symm_basis'
in rotation3D.jl but still have some interface problem to be discussed
"""
# Equation (1.13) - LI coefficients(& corresponding μ) over nn, ll
function yvec_symm_basis(A::Rot3DCoeffs, nn::StaticVector{N}, ll::StaticVector{N}, φ::Sphericalvector) where {N}
	if mod(sum(ll) + φ._valL, 2) ≠ 0
		if mod(sum(ll), 2) ≠ 0
			@warn ("To gain reflection covariant, sum of `ll` shall be even")
		else
			@warn ("To gain reflection covariant, sum of `ll` shall be odd")
		end
	end
	G, C = Gramian(A, nn, ll, φ);
	D = Rotation_D_matrix(φ);
	Dt = D[:,1];
	μt = [Dt[i].μ for i in 1:2φ._valL+1];
#	mt = [Dt[i].m for i in 1:2φ._valL+1];
	S = svd(G);
	rk = rank(G; rtol =  1e-8);
	μ_list = collect_m(ll,μt)
	Urcpi = [zeros(2φ._valL + 1) for i = 1:rk, j = 1:length(μ_list)];
	U = S.U[:, 1:rk];
	Sigma = S.S[1:rk]
	Urcpi = C' * U * Diagonal(sqrt.(Sigma))^(-1);
	return Urcpi', μ_list
end

## By using this function we could achieve actually the same thing
function getIntfromVal(::Val{L}) where{L}
	return L
end

##
end
