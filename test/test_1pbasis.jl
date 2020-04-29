
@testset "1-Particle Basis"  begin

##

using SHIPs
using Printf, Test, LinearAlgebra, JuLIP, JuLIP.Testing
using JuLIP: evaluate, evaluate_d


##

maxdeg = 15
r0 = 1.0
rcut = 3.0

trans = PolyTransform(1, r0)
Pr = transformed_jacobi(maxdeg, trans, rcut; pcut = 2)


Nat = 15
P1 = SHIPs.BasicPSH1pBasis(Pr; species = :X)
Rs, Zs, z0 = SHIPs.rand_nhd(Nat, Pr, :X)
evaluate(P1, Rs, Zs, z0)

for species in (:X, :Si, [:C, :O, :H])
   Nat = 15
   P1 = SHIPs.BasicPSH1pBasis(Pr; species = species)
   for ntest = 1:10
      Rs, Zs, z0 = SHIPs.rand_nhd(Nat, Pr, species)
      A = evaluate(P1, Rs, Zs, z0)
      A_ = sum( evaluate(P1, R, Z, z0).A for (R, Z) in zip(Rs, Zs) )
      print_tf(@test A.A ≈ A_)
   end
end

##



##

end
