"""
    FEMMHeatDiffSurfModule

Module for operations on boundaries of domains to construct system matrices and
system vectors for linear heat diffusion/conduction.
"""
module FEMMHeatDiffSurfModule

using FinEtools.FTypesModule: FInt, FFlt, FCplxFlt, FFltVec, FIntVec, FFltMat, FIntMat, FMat, FVec, FDataDict
using FinEtools.FENodeSetModule: FENodeSet
using FinEtools.FESetModule: AbstractFESet, nodesperelem, manifdim
using FinEtools.IntegDomainModule: IntegDomain, integrationdata, Jacobiansurface
using FinEtools.FieldModule: ndofs, gatherdofnums!, gatherfixedvalues_asvec!, gathervalues_asvec!, gathervalues_asmat!, nalldofs
using FinEtools.NodalFieldModule: NodalField
using FinEtools.AssemblyModule: AbstractSysvecAssembler, AbstractSysmatAssembler, SysmatAssemblerSparseSymm, startassembly!, assemble!, makematrix!, makevector!, SysvecAssembler
import FinEtools.FEMMBaseModule: AbstractFEMM
using FinEtools.FEMMBaseModule: bilform_dot
using FinEtools.MatrixUtilityModule: add_gkgt_ut_only!, add_nnt_ut_only!, complete_lt!, locjac!
using LinearAlgebra: norm, dot, cross
using FinEtools.DataCacheModule: DataCache

"""
    FEMMHeatDiffSurf{S<:AbstractFESet, F<:Function} <: AbstractFEMM

    Type for heat diffusion finite element modeling machine for boundary integrals.
"""
mutable struct FEMMHeatDiffSurf{ID<:IntegDomain} <: AbstractFEMM
    integdomain::ID # geometry data
    surfacetransfercoeff::FFlt # material object
end

"""
    surfacetransfer(self::FEMMHeatDiffSurf,  assembler::A,
      geom::NodalField{FFlt}, temp::NodalField{FFlt}) where {A<:AbstractSysmatAssembler}

Compute the surface heat transfer matrix.

# Arguments
- `self` = model machine,
- `assembler` = matrix assembler
- `geom` = geometry field,
- `temp` = temperature field
"""
function surfacetransfer(self::FEMMHeatDiffSurf,  assembler::A, geom::NodalField{FFlt}, temp::NodalField{FFlt}) where {A<:AbstractSysmatAssembler}
    return bilform_dot(self, assembler, geom, temp, DataCache(self.surfacetransfercoeff); m = 2); # two dimensional, surface, domain
end

function surfacetransfer(self::FEMMHeatDiffSurf, geom::NodalField{FFlt}, temp::NodalField{FFlt})
    assembler = SysmatAssemblerSparseSymm()
    return  surfacetransfer(self, assembler, geom, temp);
end

"""
    surfacetransferloads(self::FEMMHeatDiffSurf,  assembler::A,
      geom::NodalField{FFlt}, temp::NodalField{FFlt},
      ambtemp::NodalField{FFlt}) where {A<:AbstractSysvecAssembler}

Compute the load vector corresponding to surface heat transfer.

# Arguments
- `self` = model machine,
- `assembler` = matrix assembler
- `geom` = geometry field,
- `temp` = temperature field
- `ambtemp` = ambient temperature field on the surface
"""
function surfacetransferloads(self::FEMMHeatDiffSurf,  assembler::A,  geom::NodalField{FFlt}, temp::NodalField{FFlt},  ambtemp::NodalField{FFlt}) where {A<:AbstractSysvecAssembler}
    fes = self.integdomain.fes
    # Constants
    nfes = count(fes); # number of finite elements in the set
    ndn = ndofs(temp); # number of degrees of freedom per node
    nne = nodesperelem(fes); # number of nodes for element
    sdim = ndofs(geom);            # number of space dimensions
    mdim = manifdim(fes); # manifold dimension of the element
    Hedim = ndn*nne;             # dimension of the element matrix
    # Precompute basis f. values + basis f. gradients wrt parametric coor
    npts,  Ns,  gradNparams,  w,  pc = integrationdata(self.integdomain);
    # Prepare assembler and temporaries
    ecoords = fill(zero(FFlt), nne, ndofs(geom)); # array of Element coordinates
    Fe = fill(zero(FFlt), Hedim, 1); # element matrix -- used as a buffer
    dofnums = zeros(FInt, Hedim); # degree of freedom array -- used as a buffer
    loc = fill(zero(FFlt), 1, sdim); # quadrature point location -- used as a buffer
    J = fill(zero(FFlt), sdim, mdim); # Jacobian matrix -- used as a buffer
    pT = fill(zero(FFlt), Hedim);
    startassembly!(assembler, nalldofs(temp));
    for i in 1:count(fes)  # Loop over elements
        gathervalues_asvec!(ambtemp, pT, fes.conn[i]);# retrieve ambient temp
        if norm(pT, Inf) != 0.0    # Is the load nonzero?
            gathervalues_asmat!(geom, ecoords, fes.conn[i]);
            fill!(Fe,  0.0); # Initialize element matrix
            for j=1:npts # Loop over quadrature points
                locjac!(loc, J, ecoords, Ns[j], gradNparams[j])
                Jac = Jacobiansurface(self.integdomain, J, loc, fes.conn[i],  Ns[j]);
                Ta = dot(vec(pT), vec(Ns[j]))
                factor = Ta*self.surfacetransfercoeff*Jac*w[j]
                Fe .+= factor*Ns[j]
            end # Loop over quadrature points
            gatherdofnums!(temp, dofnums, fes.conn[i]); # retrieve degrees of freedom
            assemble!(assembler,  Fe,  dofnums); # assemble element load vector
        end
    end
    F = makevector!(assembler);
    return F
end

function surfacetransferloads(self::FEMMHeatDiffSurf,
                                        geom::NodalField{FFlt},
                                        temp::NodalField{FFlt},
                                        ambtemp::NodalField{FFlt})
    assembler = SysvecAssembler()
    return  surfacetransferloads(self, assembler, geom, temp, ambtemp);
end

end
