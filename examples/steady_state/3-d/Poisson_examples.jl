"""
Heat conduction example described by Amuthan A. Ramabathiran
http://www.codeproject.com/Articles/579983/Finite-Element-programming-in-Julia:
Unit cube, with known temperature distribution along the boundary,
and uniform heat generation rate inside.
Version: 03/03/2023
"""


module Poisson_examples
using FinEtools
using FinEtools.AssemblyModule
using FinEtools.MeshExportModule
using FinEtoolsHeatDiff
using ChunkSplitters
using DataDrop
using SparseArrays: lu

include("adhoc_assembler.jl")
include("dict_assembler.jl")
include("sparspak_assembler.jl")

function Poisson_FE_H20_example(N = 25)

end # Poisson_FE_H20_example


function Poisson_FE_T10_example(N = 25)
    println("""
        Mesh of regular QUADRATIC TETRAHEDRA, in a grid of $N x $N x $N edges.
        Version: 03/03/2023
        """
        )

    t0 = time()

    A = 1.0 # dimension of the domain (length of the side of the square)
    thermal_conductivity = [i==j ? one(FFlt) : zero(FFlt) for i=1:3, j=1:3]; # conductivity matrix
    Q = -6.0; # internal heat generation rate
    function getsource!(forceout::FFltVec, XYZ::FFltMat, tangents::FFltMat, fe_label::FInt)
        forceout[1] = Q; #heat source
    end
    tempf(x) = (1.0 .+ x[:,1].^2 + 2.0 .* x[:,2].^2);#the exact distribution of temperature



    println("Mesh generation")
    fens,fes = T10block(A, A, A, N, N, N)

    geom = NodalField(fens.xyz)
    Temp = NodalField(zeros(size(fens.xyz,1),1))

    println("Searching nodes  for BC")
    Tolerance = 1.0/N/100.0
    l1 = selectnode(fens; box=[0. 0. 0. A 0. A], inflate = Tolerance)
    l2 = selectnode(fens; box=[A A 0. A 0. A], inflate = Tolerance)
    l3 = selectnode(fens; box=[0. A 0. 0. 0. A], inflate = Tolerance)
    l4 = selectnode(fens; box=[0. A A A 0. A], inflate = Tolerance)
    l5 = selectnode(fens; box=[0. A 0. A 0. 0.], inflate = Tolerance)
    l6 = selectnode(fens; box=[0. A 0. A A A], inflate = Tolerance)
    List = vcat(l1, l2, l3, l4, l5, l6)
    setebc!(Temp, List, true, 1, tempf(geom.values[List,:])[:])
    applyebc!(Temp)
    numberdofs!(Temp)

    println( "Number of free degrees of freedom: $(Temp.nfreedofs)")
    t1 = time()

    material = MatHeatDiff(thermal_conductivity)

    femm = FEMMHeatDiff(IntegDomain(fes, TetRule(4)), material)


    println("Conductivity")
    K = conductivity(femm, geom, Temp)
    println("Nonzero EBC")
    F2 = nzebcloadsconductivity(femm, geom, Temp);
    println("Internal heat generation")
    # fi = ForceIntensity(FFlt, getsource!);# alternative  specification
    fi = ForceIntensity(FFlt[Q]);
    F1 = distribloads(femm, geom, Temp, fi, 3);

    println("Solution of the system")
    U = K\(F1+F2)
    scattersysvec!(Temp,U[:])

    println("Total time elapsed = $(time() - t0) [s]")
    println("Solution time elapsed = $(time() - t1) [s]")

    Error= 0.0
    for k=1:size(fens.xyz,1)
        Error = Error + abs.(Temp.values[k,1] - tempf(reshape(fens.xyz[k,:], (1,3)))[1])
    end
    println("Error =$Error")


    # File =  "a.vtk"
    # MeshExportModule.vtkexportmesh (File, fes.conn, [geom.values Temp.values], MeshExportModule.T3; scalars=Temp.values, scalars_name ="Temperature")

    true

end # Poisson_FE_T10_example


function Poisson_FE_T4_example(N = 25)
    println("""
        Mesh of regular LINEAR TETRAHEDRA, in a grid of $N x $N x $N edges.
        Version: 03/03/2023
        """
        )
    t0 = time()

    A = 1.0 # dimension of the domain (length of the side of the square)
    thermal_conductivity = [i==j ? one(FFlt) : zero(FFlt) for i=1:3, j=1:3]; # conductivity matrix
    Q = -6.0; # internal heat generation rate
    function getsource!(forceout::FFltVec, XYZ::FFltMat, tangents::FFltMat, fe_label::FInt)
        forceout[1] = Q; #heat source
    end
    tempf(x) = (1.0 .+ x[:,1].^2 + 2.0 .* x[:,2].^2);#the exact distribution of temperature


    println("Mesh generation")
    fens,fes = T4block(A, A, A, N, N, N)

    println("""
    Heat conduction example described by Amuthan A. Ramabathiran
    http://www.codeproject.com/Articles/579983/Finite-Element-programming-in-Julia:
    Unit cube, with known temperature distribution along the boundary,
    and uniform heat generation rate inside.  Mesh of regular LINEAR TETRAHEDRA,
    in a grid of $(N) x $(N) x $(N) edges ($(count(fens)) nodes).
    Version: 03/03/2023
    """
    )

    geom = NodalField(fens.xyz)
    Temp = NodalField(zeros(size(fens.xyz,1),1))

    println("Searching nodes  for BC")
    Tolerance = 1.0/N/100.0
    l1 = selectnode(fens; box=[0. 0. 0. A 0. A], inflate = Tolerance)
    l2 = selectnode(fens; box=[A A 0. A 0. A], inflate = Tolerance)
    l3 = selectnode(fens; box=[0. A 0. 0. 0. A], inflate = Tolerance)
    l4 = selectnode(fens; box=[0. A A A 0. A], inflate = Tolerance)
    l5 = selectnode(fens; box=[0. A 0. A 0. 0.], inflate = Tolerance)
    l6 = selectnode(fens; box=[0. A 0. A A A], inflate = Tolerance)
    List = vcat(l1, l2, l3, l4, l5, l6)
    setebc!(Temp, List, true, 1, tempf(geom.values[List,:])[:])
    applyebc!(Temp)
    numberdofs!(Temp)

    println( "Number of free degrees of freedom: $(Temp.nfreedofs)")
    t1 = time()

    material = MatHeatDiff(thermal_conductivity)

    femm = FEMMHeatDiff(IntegDomain(fes, TetRule(1)), material)


    println("Conductivity")
    K = conductivity(femm, geom, Temp)
    println("Nonzero EBC")
    F2 = nzebcloadsconductivity(femm, geom, Temp);
    println("Internal heat generation")
    # fi = ForceIntensity(FFlt, getsource!);# alternative  specification
    fi = ForceIntensity(FFlt[Q]);
    F1 = distribloads(femm, geom, Temp, fi, 3);

    println("Solution of the system")
    U = K\(F1+F2)
    scattersysvec!(Temp,U[:])

    println("Total time elapsed = $(time() - t0) [s]")
    println("Solution time elapsed = $(time() - t1) [s]")

    Error= 0.0
    for k=1:size(fens.xyz,1)
        Error = Error + abs.(Temp.values[k,1] - tempf(reshape(fens.xyz[k,:], (1,3)))[1])
    end
    println("Error =$Error")


    # File =  "a.vtk"
    # MeshExportModule.vtkexportmesh (File, fes.conn, [geom.values Temp.values], MeshExportModule.T3; scalars=Temp.values, scalars_name ="Temperature")

    true

end # Poisson_FE_T4_example

function Poisson_FE_H20_parass_tasks_example(N = 25)
    @info "Starting"

    A = 1.0 # dimension of the domain (length of the side of the square)
    thermal_conductivity = [i==j ? one(FFlt) : zero(FFlt) for i=1:3, j=1:3]; # conductivity matrix
    Q = -6.0; # internal heat generation rate
    function getsource!(forceout::FFltVec, XYZ::FFltMat, tangents::FFltMat, fe_label::FInt)
        forceout[1] = Q; #heat source
    end
    tempf(x) = (1.0 .+ x[:,1].^2 + 2.0 .* x[:,2].^2);#the exact distribution of temperature1

    fens,fes = H20block(A, A, A, N, N, N)
    @info("$(count(fes)) elements")

    geom = NodalField(fens.xyz)
    Temp = NodalField(zeros(size(fens.xyz,1),1))

    Tolerance = 1.0/N/100.0
    l1 = selectnode(fens; box=[0. 0. 0. A 0. A], inflate = Tolerance)
    l2 = selectnode(fens; box=[A A 0. A 0. A], inflate = Tolerance)
    l3 = selectnode(fens; box=[0. A 0. 0. 0. A], inflate = Tolerance)
    l4 = selectnode(fens; box=[0. A A A 0. A], inflate = Tolerance)
    l5 = selectnode(fens; box=[0. A 0. A 0. 0.], inflate = Tolerance)
    l6 = selectnode(fens; box=[0. A 0. A A A], inflate = Tolerance)
    List = vcat(l1, l2, l3, l4, l5, l6)
    setebc!(Temp, List, true, 1, tempf(geom.values[List,:])[:])
    applyebc!(Temp)
    numberdofs!(Temp)

    @info( "Number of free degrees of freedom: $(Temp.nfreedofs)")

    material = MatHeatDiff(thermal_conductivity)

    femm = FEMMHeatDiff(IntegDomain(fes, GaussRule(3, 3)), material)

    function _update_buffer_range(elem_mat_nrows, elem_mat_ncols, range, iend)
        buffer_length = elem_mat_nrows * elem_mat_ncols * length(range)
        istart = iend + 1
        iend = iend + buffer_length
        buffer_range = istart:iend
        return buffer_range, iend
    end

    function _task_local_assembler(a, buffer_range)
        buffer_length = maximum(buffer_range) - minimum(buffer_range) + 1
        matbuffer = view(a.matbuffer, buffer_range)
        rowbuffer = view(a.rowbuffer, buffer_range)
        colbuffer = view(a.colbuffer, buffer_range)
        buffer_pointer = 1
        nomatrixresult = true
        return SysmatAssemblerSparseAdHoc(buffer_length, matbuffer, rowbuffer, colbuffer, buffer_pointer, ndofs_row, ndofs_col, nomatrixresult)
    end

    nne = nodesperelem(fes)

    @info("Conductivity: serial")
    start = time()
    a = SysmatAssemblerSparseAdHoc(0.0, true)
    conductivity(femm, a, geom, Temp)
    @info "Conductivity done serial $(time() - start)"
    # DataDrop.store_matrix("I", a.rowbuffer)
    # DataDrop.store_matrix("J", a.colbuffer)
    # DataDrop.store_matrix("V", a.matbuffer)
    a.nomatrixresult = false
    K = makematrix!(a)
    @info "All done serial $(time() - start)"
    K = nothing
    a = nothing
    GC.gc()




    @info("Conductivity: parallel")
    start = time()
    a = SysmatAssemblerSparseAdHoc(0.0)
    elem_mat_nrows = nne
    elem_mat_ncols = nne
    elem_mat_nmatrices = count(fes)
    ndofs_row = Temp.nfreedofs
    ndofs_col = Temp.nfreedofs
    startassembly!(a, elem_mat_nrows, elem_mat_ncols, elem_mat_nmatrices, ndofs_row, ndofs_col)
    ntasks = Base.Threads.nthreads() - 1
    @assert ntasks >= 1
    iend = 0;
    Threads.@sync begin
        for ch in chunks(1:count(fes), ntasks)
            @info "$(ch[2]): Started $(time() - start)"
            buffer_range, iend = _update_buffer_range(elem_mat_nrows, elem_mat_ncols, ch[1], iend)
            Threads.@spawn let r =  $ch[1], b = $buffer_range
                @info "$(ch[2]): Spawned $(time() - start)"
                femm1 = FEMMHeatDiff(IntegDomain(subset(fes, r), GaussRule(3, 3)), material)
                _a = _task_local_assembler(a, b)
                @info "$(ch[2]): Started conductivity $(time() - start)"
                conductivity(femm1, _a, geom, Temp)
                @info "$(ch[2]): Finished $(time() - start)"
            end
        end
    end
    @info "Started make-matrix $(time() - start)"
    a.buffer_pointer = iend
    K = makematrix!(a)
    @info "All done $(time() - start)"
    @info "Short-circuited exit"
    return true # short-circuit for assembly testing

    # K = conductivity(femm, geom, Temp)

    F2 = nzebcloadsconductivity(femm, geom, Temp);

    # fi = ForceIntensity(FFlt, getsource!);# alternative  specification
    fi = ForceIntensity(FFlt[Q]);
    F1 = distribloads(femm, geom, Temp, fi, 3);



    U = K\(F1+F2)
    scattersysvec!(Temp, U[:])

    Error= 0.0
    for k=1:size(fens.xyz,1)
        Error = Error + abs.(Temp.values[k,1] - tempf(reshape(fens.xyz[k,:], (1,3)))[1])
    end
    @info("Error =$Error")


    File =  "Poisson_FE_H20_parass_tasks_example.vtk"
    MeshExportModule.VTK.vtkexportmesh(File, fes.conn, geom.values, MeshExportModule.VTK.H20; scalars=[("T", Temp.values, )])

    true

end # Poisson_FE_H20_parass_tasks_example

function Poisson_FE_H20_parass_threads_example(N = 25)
    @info "Starting"

    A = 1.0 # dimension of the domain (length of the side of the square)
    thermal_conductivity = [i==j ? one(FFlt) : zero(FFlt) for i=1:3, j=1:3]; # conductivity matrix
    Q = -6.0; # internal heat generation rate
    function getsource!(forceout::FFltVec, XYZ::FFltMat, tangents::FFltMat, fe_label::FInt)
        forceout[1] = Q; #heat source
    end
    tempf(x) = (1.0 .+ x[:,1].^2 + 2.0 .* x[:,2].^2);#the exact distribution of temperature1

    fens,fes = H20block(A, A, A, N, N, N)
    @info("$(count(fes)) elements")

    geom = NodalField(fens.xyz)
    Temp = NodalField(zeros(size(fens.xyz,1),1))

    Tolerance = 1.0/N/100.0
    l1 = selectnode(fens; box=[0. 0. 0. A 0. A], inflate = Tolerance)
    l2 = selectnode(fens; box=[A A 0. A 0. A], inflate = Tolerance)
    l3 = selectnode(fens; box=[0. A 0. 0. 0. A], inflate = Tolerance)
    l4 = selectnode(fens; box=[0. A A A 0. A], inflate = Tolerance)
    l5 = selectnode(fens; box=[0. A 0. A 0. 0.], inflate = Tolerance)
    l6 = selectnode(fens; box=[0. A 0. A A A], inflate = Tolerance)
    List = vcat(l1, l2, l3, l4, l5, l6)
    setebc!(Temp, List, true, 1, tempf(geom.values[List,:])[:])
    applyebc!(Temp)
    numberdofs!(Temp)

    @info( "Number of free degrees of freedom: $(Temp.nfreedofs)")

    material = MatHeatDiff(thermal_conductivity)

    femm = FEMMHeatDiff(IntegDomain(fes, GaussRule(3, 3)), material)

    function _update_buffer_range(elem_mat_nrows, elem_mat_ncols, range, iend)
        buffer_length = elem_mat_nrows * elem_mat_ncols * length(range)
        istart = iend + 1
        iend = iend + buffer_length
        buffer_range = istart:iend
        return buffer_range, iend
    end

    function _task_local_assembler(a, buffer_range)
        buffer_length = maximum(buffer_range) - minimum(buffer_range) + 1
        matbuffer = view(a.matbuffer, buffer_range)
        rowbuffer = view(a.rowbuffer, buffer_range)
        colbuffer = view(a.colbuffer, buffer_range)
        buffer_pointer = 1
        nomatrixresult = true
        return SysmatAssemblerSparseAdHoc(buffer_length, matbuffer, rowbuffer, colbuffer, buffer_pointer, ndofs_row, ndofs_col, nomatrixresult)
    end

    nne = nodesperelem(fes)

    @info("Conductivity: serial")
    start = time()
    a = SysmatAssemblerSparseAdHoc(0.0, true)
    conductivity(femm, a, geom, Temp)
    @info "Conductivity done serial $(time() - start)"
    # DataDrop.store_matrix("I", a.rowbuffer[1:a.buffer_pointer-1])
    # DataDrop.store_matrix("J", a.colbuffer[1:a.buffer_pointer-1])
    # DataDrop.store_matrix("V", a.matbuffer[1:a.buffer_pointer-1])
    a.nomatrixresult = false
    K = makematrix!(a)
    @info "All done serial $(time() - start)"
    K = nothing
    a = nothing
    GC.gc()

    @info("Conductivity: parallel")
    start = time()
    a = SysmatAssemblerSparseAdHoc(0.0)
    elem_mat_nrows = nne
    elem_mat_ncols = nne
    elem_mat_nmatrices = count(fes)
    ndofs_row = Temp.nfreedofs
    ndofs_col = Temp.nfreedofs
    startassembly!(a, elem_mat_nrows, elem_mat_ncols, elem_mat_nmatrices, ndofs_row, ndofs_col)
    @info "Creating thread structures $(time() - start)"
    ntasks = Base.Threads.nthreads()
    _a = []
    _r = []
    iend = 0;
    for ch in chunks(1:count(fes), ntasks)
        buffer_range, iend = _update_buffer_range(elem_mat_nrows, elem_mat_ncols, ch[1], iend)
        push!(_a, _task_local_assembler(a, buffer_range))
        push!(_r, ch[1])
    end
    @info "Finished $(time() - start)"
    Threads.@threads for th in eachindex(_a)
        @info "$(th): Started $(time() - start)"
        femm1 = FEMMHeatDiff(IntegDomain(subset(fes, _r[th]), GaussRule(3, 3)), material)
        conductivity(femm1, _a[th], geom, Temp)
        @info "$(th): Finished $(time() - start)"
    end
    @info "Started make-matrix $(time() - start)"
    @show a.buffer_pointer = iend
    K = makematrix!(a)
    @info "All done $(time() - start)"
    @info "Short-circuited exit"
    return true # short-circuit for assembly testing

    # K = conductivity(femm, geom, Temp)

    F2 = nzebcloadsconductivity(femm, geom, Temp);

    # fi = ForceIntensity(FFlt, getsource!);# alternative  specification
    fi = ForceIntensity(FFlt[Q]);
    F1 = distribloads(femm, geom, Temp, fi, 3);



    U = K\(F1+F2)
    scattersysvec!(Temp, U[:])

    Error= 0.0
    for k=1:size(fens.xyz,1)
        Error = Error + abs.(Temp.values[k,1] - tempf(reshape(fens.xyz[k,:], (1,3)))[1])
    end
    @info("Error =$Error")


    File =  "Poisson_FE_H20_parass_threads_example.vtk"
    MeshExportModule.VTK.vtkexportmesh(File, fes.conn, geom.values, MeshExportModule.VTK.H20; scalars=[("T", Temp.values, )])

    true

end # Poisson_FE_H20_parass_threads_example

function Poisson_FE_H8_parass_threads_example(N = 25)
    @info "Starting"

    A = 1.0 # dimension of the domain (length of the side of the square)
    thermal_conductivity = [i==j ? one(FFlt) : zero(FFlt) for i=1:3, j=1:3]; # conductivity matrix
    Q = -6.0; # internal heat generation rate
    function getsource!(forceout::FFltVec, XYZ::FFltMat, tangents::FFltMat, fe_label::FInt)
        forceout[1] = Q; #heat source
    end
    tempf(x) = (1.0 .+ x[:,1].^2 + 2.0 .* x[:,2].^2);#the exact distribution of temperature1

    fens,fes = H8block(A, A, A, N, N, N)
    @info("$(count(fes)) elements")

    geom = NodalField(fens.xyz)
    Temp = NodalField(zeros(size(fens.xyz,1),1))

    Tolerance = 1.0/N/100.0
    l1 = selectnode(fens; box=[0. 0. 0. A 0. A], inflate = Tolerance)
    l2 = selectnode(fens; box=[A A 0. A 0. A], inflate = Tolerance)
    l3 = selectnode(fens; box=[0. A 0. 0. 0. A], inflate = Tolerance)
    l4 = selectnode(fens; box=[0. A A A 0. A], inflate = Tolerance)
    l5 = selectnode(fens; box=[0. A 0. A 0. 0.], inflate = Tolerance)
    l6 = selectnode(fens; box=[0. A 0. A A A], inflate = Tolerance)
    List = vcat(l1, l2, l3, l4, l5, l6)
    setebc!(Temp, List, true, 1, tempf(geom.values[List,:])[:])
    applyebc!(Temp)
    numberdofs!(Temp)

    @info( "Number of free degrees of freedom: $(Temp.nfreedofs)")

    material = MatHeatDiff(thermal_conductivity)

    femm = FEMMHeatDiff(IntegDomain(fes, GaussRule(3, 2)), material)

    function _update_buffer_range(elem_mat_nrows, elem_mat_ncols, range, iend)
        buffer_length = elem_mat_nrows * elem_mat_ncols * length(range)
        istart = iend + 1
        iend = iend + buffer_length
        buffer_range = istart:iend
        return buffer_range, iend
    end

    function _task_local_assembler(a, buffer_range)
        buffer_length = maximum(buffer_range) - minimum(buffer_range) + 1
        matbuffer = view(a.matbuffer, buffer_range)
        rowbuffer = view(a.rowbuffer, buffer_range)
        colbuffer = view(a.colbuffer, buffer_range)
        buffer_pointer = 1
        nomatrixresult = true
        return SysmatAssemblerSparseAdHoc(buffer_length, matbuffer, rowbuffer, colbuffer, buffer_pointer, ndofs_row, ndofs_col, nomatrixresult)
    end

    nne = nodesperelem(fes)

    @info("Conductivity: serial")
    start = time()
    a = SysmatAssemblerSparseAdHoc(0.0, true)
    conductivity(femm, a, geom, Temp)
    @info "Conductivity done serial $(time() - start)"
    # DataDrop.store_matrix("I", a.rowbuffer[1:a.buffer_pointer-1])
    # DataDrop.store_matrix("J", a.colbuffer[1:a.buffer_pointer-1])
    # DataDrop.store_matrix("V", a.matbuffer[1:a.buffer_pointer-1])
    a.nomatrixresult = false
    K = makematrix!(a)
    @info "All done serial $(time() - start)"
    K = nothing
    a = nothing
    GC.gc()

    @info("Conductivity: parallel")
    start = time()
    a = SysmatAssemblerSparseAdHoc(0.0)
    elem_mat_nrows = nne
    elem_mat_ncols = nne
    elem_mat_nmatrices = count(fes)
    ndofs_row = Temp.nfreedofs
    ndofs_col = Temp.nfreedofs
    startassembly!(a, elem_mat_nrows, elem_mat_ncols, elem_mat_nmatrices, ndofs_row, ndofs_col)
    @info "Creating thread structures $(time() - start)"
    ntasks = Base.Threads.nthreads()
    _a = []
    _r = []
    iend = 0;
    for ch in chunks(1:count(fes), ntasks)
        buffer_range, iend = _update_buffer_range(elem_mat_nrows, elem_mat_ncols, ch[1], iend)
        push!(_a, _task_local_assembler(a, buffer_range))
        push!(_r, ch[1])
    end
    @info "Finished $(time() - start)"
    Threads.@threads for th in eachindex(_a)
        @info "$(th): Started $(time() - start)"
        femm1 = FEMMHeatDiff(IntegDomain(subset(fes, _r[th]), GaussRule(3, 2)), material)
        conductivity(femm1, _a[th], geom, Temp)
        @info "$(th): Finished $(time() - start)"
    end
    @info "Started make-matrix $(time() - start)"
    @show a.buffer_pointer = iend
    K = makematrix!(a)
    @info "All done $(time() - start)"
    @info "Short-circuited exit"
    return true # short-circuit for assembly testing

    # K = conductivity(femm, geom, Temp)

    F2 = nzebcloadsconductivity(femm, geom, Temp);

    # fi = ForceIntensity(FFlt, getsource!);# alternative  specification
    fi = ForceIntensity(FFlt[Q]);
    F1 = distribloads(femm, geom, Temp, fi, 3);



    U = K\(F1+F2)
    scattersysvec!(Temp, U[:])

    Error= 0.0
    for k=1:size(fens.xyz,1)
        Error = Error + abs.(Temp.values[k,1] - tempf(reshape(fens.xyz[k,:], (1,3)))[1])
    end
    @info("Error =$Error")


    File =  "Poisson_FE_H8_parass_threads_example.vtk"
    MeshExportModule.VTK.vtkexportmesh(File, fes.conn, geom.values, MeshExportModule.VTK.H8; scalars=[("T", Temp.values, )])

    true

end # Poisson_FE_H20_parass_threads_example

function Poisson_FE_T4_altass_example(N = 25)
    t0 = time()

    A = 1.0 # dimension of the domain (length of the side of the square)
    thermal_conductivity = [i==j ? one(FFlt) : zero(FFlt) for i=1:3, j=1:3]; # conductivity matrix
    Q = -6.0; # internal heat generation rate
    function getsource!(forceout::FFltVec, XYZ::FFltMat, tangents::FFltMat, fe_label::FInt)
        forceout[1] = Q; #heat source
    end
    tempf(x) = (1.0 .+ x[:,1].^2 + 2.0 .* x[:,2].^2);#the exact distribution of temperature

    println("Mesh generation")
    fens,fes = T4block(A, A, A, N, N, N)

    geom = NodalField(fens.xyz)
    Temp = NodalField(zeros(size(fens.xyz,1),1))

    println("Searching nodes  for BC")
    Tolerance = 1.0/N/100.0
    l1 = selectnode(fens; box=[0. 0. 0. A 0. A], inflate = Tolerance)
    l2 = selectnode(fens; box=[A A 0. A 0. A], inflate = Tolerance)
    l3 = selectnode(fens; box=[0. A 0. 0. 0. A], inflate = Tolerance)
    l4 = selectnode(fens; box=[0. A A A 0. A], inflate = Tolerance)
    l5 = selectnode(fens; box=[0. A 0. A 0. 0.], inflate = Tolerance)
    l6 = selectnode(fens; box=[0. A 0. A A A], inflate = Tolerance)
    List = vcat(l1, l2, l3, l4, l5, l6)
    setebc!(Temp, List, true, 1, tempf(geom.values[List,:])[:])
    applyebc!(Temp)
    numberdofs!(Temp)

    println( "Number of free degrees of freedom: $(Temp.nfreedofs)")
    t1 = time()

    material = MatHeatDiff(thermal_conductivity)

    femm = FEMMHeatDiff(IntegDomain(fes, TetRule(1)), material)


    println("Conductivity")
    # ass = AssemblyModule.SysmatAssemblerSparse(0.0, true)
    # @time     K = conductivity(femm, ass, geom, Temp)
    # ass.nomatrixresult = false
    # @time K = makematrix!(ass)

    # ass = SysmatAssemblerSparseDict(0.0, true)
    # @time     K = conductivity(femm, ass, geom, Temp)
    # ass.nomatrixresult = false
    # @time K = makematrix!(ass)

    ass = SysmatAssemblerSparspak(0.0, true)
    @time     K = conductivity(femm, ass, geom, Temp)
    ass.nomatrixresult = false
    @time K = makematrix!(ass)

    # @warn "Short circuit exit"
    # return

    println("Nonzero EBC")
    F2 = nzebcloadsconductivity(femm, geom, Temp);
    println("Internal heat generation")
    # fi = ForceIntensity(FFlt, getsource!);# alternative  specification
    fi = ForceIntensity(FFlt[Q]);
    F1 = distribloads(femm, geom, Temp, fi, 3);

    println("Solution of the system")
    # U = K\(F1+F2)

    # @time fact = lu(K)
    # @time U = fact \ (F1+F2)

    solve!(K, (F1+F2))
    U = K.p.x

    scattersysvec!(Temp, U[:])

    println("Total time elapsed = $(time() - t0) [s]")
    println("Solution time elapsed = $(time() - t1) [s]")

    Error= 0.0
    for k=1:size(fens.xyz,1)
        Error = Error + abs.(Temp.values[k,1] - tempf(reshape(fens.xyz[k,:], (1,3)))[1])
    end
    println("Error =$Error")


    # File =  "a.vtk"
    # MeshExportModule.vtkexportmesh (File, fes.conn, [geom.values Temp.values], MeshExportModule.T3; scalars=Temp.values, scalars_name ="Temperature")

    true

end # Poisson_FE_T4_example

function allrun()
    println("#####################################################")
    println("# Poisson_FE_H20_parass_tasks_example ")
    Poisson_FE_H20_parass_tasks_example()
    println("#####################################################")
    println("# Poisson_FE_H20_parass_threads_example ")
    Poisson_FE_H20_parass_threads_example()
    println("#####################################################")
    println("# Poisson_FE_H20_example ")
    Poisson_FE_H20_example()
    println("#####################################################")
    println("# Poisson_FE_T10_example ")
    Poisson_FE_T10_example()
    println("#####################################################")
    println("# Poisson_FE_T4_example ")
    Poisson_FE_T4_example()
    println("#####################################################")
    println("# Poisson_FE_T4_altass_example ")
    Poisson_FE_T4_altass_example()
end # function allrun

@info "All examples may be executed with "
println("using .$(@__MODULE__); $(@__MODULE__).allrun()")

end # module Poisson_examples
nothing
