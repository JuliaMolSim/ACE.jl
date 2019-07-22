

# -------------------------------------------------------------
#       construct l,k tuples that specify basis functions
# -------------------------------------------------------------

function filter_tuples(KL, ν::StaticVector{1}, cg)
   if KL[ν[1]].l != 0
      return false
   else
      return true
   end
end

# keep this for the sake of a record and comparison with the general case
function filter_tuples(KL, ν::StaticVector{2}, cg)  # 3B version
   kl1, kl2 = KL[ν[1]], KL[ν[2]]
   if kl1.l != kl2.l
      return false
   else
      return true
   end
end

# keep this for the sake of a record and comparison with the general case
function filter_tuples(KL, ν::StaticVector{3}, cg)  # 4B version
   l1, l2, l3 = KL[ν[1]].l, KL[ν[2]].l, KL[ν[3]].l
   if !( (abs(l1-l2) <= l3 <= l1+l2) && iseven(l1+l2+l3) )
      return false
   else
      return true
   end
end

function filter_tuples(KL, ν::StaticVector{4}, cg)
   ll = SVector(ntuple(i -> KL[ν[i]].l, 4))
   # invariance under reflections
   if !iseven(sum(ll))
      return false
   end
   # requirement to define the CG coefficients
   if max(abs(ll[1]-ll[2]), abs(ll[3]-ll[4])) > min(ll[1]+ll[2], ll[3]+ll[4])
      return false
   end

   # The next part is purely a health-check, that should not be necessary!
   # basically we are checking that all basis functions that we are
   # retaining are really non-zero!
   foundnz = false
   for mpre in _mrange(ll)
      mm = SVector(Tuple(mpre)..., -sum(Tuple(mpre)))
      if abs(mm[end]) > ll[4]; continue; end
      if _Bcoeff(ll, mm, cg) != 0.0
         foundnz = true
      end
   end
   @assert foundnz

   return true
end


function filter_tuples(KL, ν::StaticVector{N}, cg) where {N}
   ll = SVector(ntuple(i -> KL[ν[i]].l, N))
   # invariance under reflections
   if !iseven(sum(ll))
      return false
   end
   # replace a "clever" computation with just checking that the CG
   # coefficients are non-zero.
   foundnz = false
   for mpre in _mrange(ll)
      mm = _mvec(mpre)
      if abs(mm[end]) > ll[end]; continue; end
      if _Bcoeff(ll, mm, cg) != 0.0
         foundnz = true
         break
      end
   end
   if !foundnz
      return false
   end

   return true
end



"""
return the coefficients derived from the Clebsch-Gordan coefficients
that guarantee rotational invariance of the B functions
"""
function _Bcoeff(ll::SVector{BO, <:Integer}, mm::SVector{BO, <:Integer}) where {BO}
   @error("general case of B-coefficients has not yet been implemented")
end

function _Bcoeff(ll::SVector{1, <:Integer}, mm::SVector{1, <:Integer}, cg)
   # @assert(ll[1] == mm[1] == 0)
   return 1.0
end

function _Bcoeff(ll::SVector{2, <:Integer}, mm::SVector{2, <:Integer}, cg)
   @assert(mm[1] + mm[2] == 0)
   return (-1)^(mm[1])
end

function _Bcoeff(ll::SVector{3, <:Integer}, mm::SVector{3, <:Integer}, cg)
   @assert(mm[1] + mm[2] + mm[3] == 0)
   c = cg(ll[1], mm[1], ll[2], mm[2], ll[3], -mm[3])
   return (-1)^(mm[3]) * c
end

function _Bcoeff(ll::SVector{4, <:Integer}, mm::SVector{4, <:Integer}, cg)
   @assert(sum(mm) == 0)
   M = mm[1]+mm[2] # == -(mm[3]+mm[4]) <=> ∑mm = 0
   c = 0.0
   for J = max(abs(ll[1]-ll[2]), abs(ll[3]-ll[4])):min(ll[1]+ll[2],ll[3]+ll[4])
      # @assert abs(M) <= J
      # TODO: revisit this issue?
      if abs(M) > J; continue; end
      c += (-1)^M * cg(ll[1], mm[1], ll[2], mm[2], J, M) *
                    cg(ll[3], mm[3], ll[4], mm[4], J, -M)
   end
   return c
end

function _Bcoeff(ll::SVector{5, <:Integer}, mm::SVector{5, <:Integer}, cg)
   @assert(sum(mm) == 0)
   c = 0.0
   M1 = mm[1] + mm[2]
   M2 = mm[1] + mm[2] + mm[3]
   for J1 = abs(ll[1] - ll[2]):(ll[1]+ll[2])
       for J2 = max(abs(J1 - ll[3]), abs(ll[4]-ll[5])):min(J1+ll[3], ll[4]+ll[5])
          if abs(M2) > J2 || abs(M1) > J1
             continue
          end
          c += (-1)^M2 * cg(ll[1], mm[1], ll[2], mm[2], J1,  M1) *
                         cg(J1,    M1,    ll[3], mm[3], J2,  M2) *
                         cg(ll[4], mm[4], ll[5], mm[5], J2, -M2)
       end
    end
    return c
end