
#################################################
# Constructors
#################################################

@doc raw"""
    cstar_surface(ls :: DoubleVector{Int64}, ds :: DoubleVector{Int64}, case :: Symbol)

Construct a C-star surface from the integral vectors $l_i=(l_{i1}, ...,
l_{in_i})$ and $d_i=(d_{i1}, ..., d_{in_i})$ and a given C-star surface case.
The parameters `ls` and `ds` are given both given as a `DoubleVector`, which is
a zero-indexed vector of one-indexed vectors. They must be of the same length
and satisfy `gcd(ls[i][j], ds[i][j]) == 1` for all `i` and `j`. The parameter
`case` can be one of the four symbols `:ee, :pe, :ep, :pp`.

# Example

The ``E_6`` singular cubic.

```jldoctest
julia> X = cstar_surface(DoubleVector([[3, 1], [3], [2]]), DoubleVector([[-2, -1], [1], [1]]), :ee)
C-star surface of type (e-e)
julia> gen_matrix(X)
[-3   -1   3   0]
[-3   -1   0   2]
[-2   -1   1   1]

```

"""
function cstar_surface(ls :: DoubleVector{Int64}, ds :: DoubleVector{Int64}, case :: Symbol)
    @req length(ls) == length(ds) "ls and ds must be of the same length"
    r = length(ls)
    @req all(i -> length(ls[i]) == length(ds[i]), axes(ls,1)) "ls[i] and ds[i] must be of the same length for all i"
    @req all2((l,d) -> gcd(l,d) == 1, ls, ds) "ls[i][j] and ds[i][j] must be coprime for all i and j"

    return CStarSurface{_case_sym_to_type(case)}(ls, ds, case)

end


@doc raw"""
    cstar_surface(ls :: Vector{Vector{Int64}}, ds :: Vector{Vector{Int64}}, case :: Symbol)

Construct a C-star surface from the integral vectors $l_i=(l_{i1}, ...,
l_{in_i})$ and $d_i=(d_{i1}, ..., d_{in_i})$ and a given C-star surface case.
The parameters `ls` and `ds` are given both given as a vector of vectors. They
must be of the same length and satisfy `gcd(ls[i][j], ds[i][j]) == 1` for all
`i` and `j`. The parameter `case` can be one of the four symbols `:ee, :pe,
:ep, :pp`.

# Example

The ``E_6`` singular cubic.

```jldoctest
julia> X = cstar_surface([[3, 1], [3], [2]], [[-2, -1], [1], [1]], :ee)
C-star surface of type (e-e)
julia> gen_matrix(X)
[-3   -1   3   0]
[-3   -1   0   2]
[-2   -1   1   1]

```

"""
cstar_surface(ls :: Vector{Vector{Int64}}, ds :: Vector{Vector{Int64}}, case :: Symbol) = cstar_surface(DoubleVector(ls), DoubleVector(ds), case)

function _is_cstar_column(v :: Vector{T}) where {T <: IntegerUnion}
    r = length(v) - 1
    v0 = v[begin : end-1]
    l = maximum(abs.(v0))
    if l == 0 return nothing end
    d = last(v)
    for i = 0 : r
        if v0 == l * basis_vector(T, r, i)
            return (i, Int(l), Int(d))
        end
    end
    return nothing
end


@doc raw"""
    cstar_surface(P :: ZZMatrix)

Construct a C-star surface from a generator matrix of the correct format. That
is, $P$ must be of one of the following forms:

```math
\begin{array}{lcclc}
\text{(e-e)} & 
\begin{bmatrix}
L \\
d
\end{bmatrix} &
\qquad &
\text{(p-e)} &
\begin{bmatrix}
L & 0 \\
d & 1
\end{bmatrix} \\

\text{(e-p)} &
\begin{bmatrix}
L & 0 \\
d & -1
\end{bmatrix} &
\qquad &
\text{(p-p)} &
\begin{bmatrix}
L & 0 & 0 \\
d & 1 & -1
\end{bmatrix}
\end{array},
```

where for some integral vectors ``l_i=(l_{i1}, ..., l_{in_i}) \in
\mathbb{Z}^{n_i}_{\geq 0}`` and ``d_i=(d_{i1}, ..., d_{in_i}) \in
\mathbb{Z}^{n_i}`` with ``\gcd(l_{ij}, d_{ij}) = 1``, we have

```math
L = \begin{bmatrix}
-l_0 & l_1 & \dots & 0 \\
\vdots & & \ddots & 0 \\
-l_0 & 0 & \dots & l_r
\end{bmatrix}, 
\qquad
d = \begin{bmatrix}
d_0 & \dots & d_r
\end{bmatrix}.
```

# Example

The ``E_6`` singular cubic.

```jldoctest
julia> cstar_surface(ZZ[-3 -1 3 0 ; -3 -1 0 2 ; -2 -1 1 1])
C-star surface of type (e-e)

```

"""
function cstar_surface(P :: ZZMatrix)
    ls = DoubleVector{Int}(undef, 0)
    ds = DoubleVector{Int}(undef, 0)
    cols = [[P[j,i] for j = 1 : nrows(P)] for i = 1 : ncols(P)]
    r = nrows(P) - 1 
    last_i = -1
    for col in cols
        ild = _is_cstar_column(col)
        
        if isnothing(ild)
            break
        end

        (i, l, d) = ild
        if i == last_i
            push!(ls[i], l)
            push!(ds[i], d)
        elseif i == last_i + 1
            push!(ls, [l])
            push!(ds, [d])
        else
            throw(ArgumentError("given matrix is not in P-Matrix shape"))
        end

        last_i = i
    end
    @req last_i == r "given matrix is not in P-Matrix shape"

    m = length(cols) - sum(map(length, ls))
    if m == 0
        case = :ee
    elseif m == 1 && last(cols) == basis_vector(r+1,r+1)
        case = :pe
    elseif m == 1 && last(cols) == -basis_vector(r+1,r+1)
        case = :ep
    elseif m == 2 && cols[end-1] == basis_vector(r+1,r+1) && last(cols) == -basis_vector(r+1,r+1)
        case = :pp
    else
        throw(ArgumentError("given matrix is not in P-Matrix shape"))
    end

    return cstar_surface(ls, ds, case)
end


#################################################
# Basic attributes
#################################################

@doc raw"""
    has_x_plus(X :: CStarSurface{<:CStarSurfaceCase})

Checks whether a given C-star surface has an elliptic fixed point in the
source, commonly denoted $x^+$.

"""
has_x_plus(X :: CStarSurface{T}) where {T <: CStarSurfaceCase} = has_x_plus(T)


@doc raw"""
    has_x_minus(X :: CStarSurface{<:CStarSurfaceCase})

Checks whether a given C-star surface has an elliptic fixed point in the
sink, commonly denoted $x^-$.

"""
has_x_minus(X :: CStarSurface{T}) where {T <: CStarSurfaceCase} = has_x_minus(T)


@doc raw"""
    has_D_plus(X :: CStarSurface{<:CStarSurfaceCase})

Checks whether a given C-star surface has a parabolic fixed point curve in the
source, commonly denoted $D^+$.

"""
has_D_plus(X :: CStarSurface{T}) where {T <: CStarSurfaceCase} = has_D_plus(T)


@doc raw"""
    has_D_minus(X :: CStarSurface{<:CStarSurfaceCase})

Checks whether a given C-star surface has a parabolic fixed point curve in the
sink, commonly denoted $D^-$.

"""
has_D_minus(X :: CStarSurface{T}) where {T <: CStarSurfaceCase} = has_D_minus(T)

@doc raw"""
    nblocks(X :: CStarSurface)

Returns the number of blocks in the generator matrix of a C-star surface.

"""
@attr nblocks(X :: CStarSurface) = length(X.l)

_r(X :: CStarSurface) = nblocks(X) - 1

_n(X :: CStarSurface, i :: Int) = length(X.l[i])
@attr _ns(X :: CStarSurface) = map(length, X.l)
@attr _n(X :: CStarSurface) = sum(_ns(X))


@doc raw"""
    block_sizes(X :: CStarSurface)   

Returns the sizes of the blocks in the generator matrix of a C-star surface.
The result is a zero-indexed vector of type `ZeroVector`.

"""
block_sizes(X :: CStarSurface) = _ns(X)

_m(X :: CStarSurface{EE}) = 0
_m(X :: CStarSurface{PE}) = 1
_m(X :: CStarSurface{EP}) = 1
_m(X :: CStarSurface{PP}) = 2



@doc raw"""
    slopes(X :: CStarSurface)

Returns the `DoubleVector` of slopes of a C-star surface, i.e a `DoubleVector`
with `slopes(X)[i][j] = X.d[i][j] // X.l[i][j]`.

"""
@attr slopes(X :: CStarSurface) = map2(//, X.d, X.l)

@attr m_plus(X :: CStarSurface) = sum(map(maximum, slopes(X)))
@attr m_minus(X :: CStarSurface) = -sum(map(minimum, slopes(X)))

@attr _slope_ordering_permutations(X :: CStarSurface) = map(v -> sortperm(v, rev=true), slopes(X))

@attr _slope_ordered_l(X :: CStarSurface) = map(getindex, X.l, _slope_ordering_permutations(X))

@attr _slope_ordered_d(X :: CStarSurface) = map(getindex, X.d, _slope_ordering_permutations(X))

@attr _l_plus(X :: CStarSurface) = sum([1 // first(_slope_ordered_l(X)[i]) for i = 0 : _r(X)]) - _r(X) + 1
@attr _l_minus(X :: CStarSurface) = sum([1 // last(_slope_ordered_l(X)[i]) for i = 0 : _r(X)]) - _r(X) + 1


@doc raw"""
    is_intrinsic_quadric(X :: CStarSurface)

Checks whether a C-star surface is an intrinsic quadric, i.e its Cox Ring
has a single quadratic relation.

"""
@attr is_intrinsic_quadric(X :: CStarSurface) = 
nblocks(X) == 3 && all(ls -> sum(ls) == 2, X.l)


_almost_all_one(v :: AbstractVector) = length(filter(x -> x > 1, v)) <= 2

@doc raw"""
    is_quasismooth(X :: CStarSurface)

Checks whether a $\mathbb{C}^*$-surface $X$ is quasismooth, i.e. its
characteristic space $\hat X$ is smooth.

# Example

```jldoctest
julia> X = cstar_surface([[2,1],[1,1],[2]], [[3,-1],[0,-1],[1]], :ee)
C-star surface of type (e-e)

julia> is_quasismooth(X)
true
```

"""
@attr is_quasismooth(X :: CStarSurface{EE}) =
_almost_all_one(first.(_slope_ordered_l(X))) &&
_almost_all_one(last.(_slope_ordered_l(X)))

@attr is_quasismooth(X :: CStarSurface{PE}) =
_almost_all_one(last.(_slope_ordered_l(X)))

@attr is_quasismooth(X :: CStarSurface{EP}) =
_almost_all_one(first.(_slope_ordered_l(X)))

@attr is_quasismooth(X :: CStarSurface{PP}) = true


#################################################
# Construction of canonical toric ambient
#################################################

@attr function _ray_indices(X :: CStarSurface) 
    ns, r = _ns(X), _r(X)
    return ZeroVector([sum(ns[0 : i-1]) .+ collect(1 : ns[i]) for i = 0 : r])
end

@attr _slope_ordered_ray_indices(X :: CStarSurface) =
map(getindex, _ray_indices(X), _slope_ordering_permutations(X))

_sigma_plus(X :: CStarSurface) = Vector(map(first, _slope_ordered_ray_indices(X)))

_sigma_minus(X :: CStarSurface) = Vector(map(last, _slope_ordered_ray_indices(X)))

_tau(X :: CStarSurface, i :: Int, j :: Int) = [_slope_ordered_ray_indices(X)[i][j], _slope_ordered_ray_indices(X)[i][j+1]]

_taus(X :: CStarSurface) = Vector{Int}[_tau(X, i, j) for i = 0 : _r(X) for j = 1 : _ns(X)[i] - 1]

_vplus_index(X :: CStarSurface{PE}) = sum(map(length, X.l)) + 1
_vplus_index(X :: CStarSurface{PP}) = sum(map(length, X.l)) + 1

_tau_plus(X :: CStarSurface, i :: Int) = [first(_slope_ordered_ray_indices(X)[i]), _vplus_index(X)]

_taus_plus(X :: CStarSurface) = Vector{Int}[_tau_plus(X, i) for i = 0 : _r(X)]

_vminus_index(X :: CStarSurface{EP}) = sum(map(length, X.l)) + 1
_vminus_index(X :: CStarSurface{PP}) = sum(map(length, X.l)) + 2

_tau_minus(X :: CStarSurface, i :: Int) = [last(_slope_ordered_ray_indices(X)[i]), _vminus_index(X)]

_taus_minus(X :: CStarSurface) = Vector{Int}[_tau_minus(X, i) for i = 0 : _r(X)]

@attr maximal_cones_indices(X :: CStarSurface{EE}) = append!(_taus(X), [_sigma_plus(X), _sigma_minus(X)])
@attr maximal_cones_indices(X :: CStarSurface{PE}) = append!(_taus(X), [_sigma_minus(X)], _taus_plus(X))
@attr maximal_cones_indices(X :: CStarSurface{EP}) = append!(_taus(X), [_sigma_plus(X)], _taus_minus(X))
@attr maximal_cones_indices(X :: CStarSurface{PP}) = append!(_taus(X), _taus_plus(X), _taus_minus(X))

_ray(X :: CStarSurface, i :: Int, j :: Int) = 
X.l[i][j] * [basis_vector(_r(X),i) ; 0] + X.d[i][j] * basis_vector(_r(X)+1, _r(X)+1)

_rays_core(X :: CStarSurface) = [_ray(X, i, j) for i in axes(X.l, 1) for j in axes(X.l[i], 1)]

_vplus(X :: CStarSurface) = basis_vector(_r(X)+1, _r(X)+1)
_vminus(X :: CStarSurface) = -basis_vector(_r(X)+1, _r(X)+1)

rays(X :: CStarSurface{EE}) = _rays_core(X)
rays(X :: CStarSurface{PE}) = push!(_rays_core(X), _vplus(X))
rays(X :: CStarSurface{EP}) = push!(_rays_core(X), _vminus(X))
rays(X :: CStarSurface{PP}) = push!(_rays_core(X), _vplus(X), _vminus(X))

_coordinate_names_core(X :: CStarSurface) = ["T[$(i)][$(j)]" for i in axes(X.l, 1) for j in axes(X.l[i], 1)]

_coordinate_names(X :: CStarSurface{EE}) = _coordinate_names_core(X)
_coordinate_names(X :: CStarSurface{PE}) = push!(_coordinate_names_core(X), "S[1]")
_coordinate_names(X :: CStarSurface{EP}) = push!(_coordinate_names_core(X), "S[1]")
_coordinate_names(X :: CStarSurface{PP}) = push!(_coordinate_names_core(X), "S[1]", "S[2]")

@doc raw"""
    canonical_toric_ambient(X :: CStarSurface) 

Construct the canonical toric ambient of a C-star surface, as an Oscar type.

# Example

```jldoctest
julia> X = cstar_surface([[3, 1], [3], [2]], [[-2, -1], [1], [1]], :ee)
C-star surface of type (e-e)

julia> Z = canonical_toric_ambient(X)
Normal toric variety

julia> rays(Z)
4-element SubObjectIterator{RayVector{QQFieldElem}}:
 [-1, -1, -2//3]
 [-1, -1, -1]
 [1, 0, 1//3]
 [0, 1, 1//2]
```

"""
@attr function canonical_toric_ambient(X :: CStarSurface) 
    # passing non_redundant=true does two important things here:
    # 1. It skips time-consuming checks on the input rays,
    # 2. It prevents polymake from reordering the rays, making the interface to
    # toric geometry in Oscar much more reliable.
    Z = normal_toric_variety(rays(X), maximal_cones_indices(X); non_redundant=true)
    set_coordinate_names(Z, _coordinate_names(X))
    return Z
end


#################################################
# Fixed points
#################################################

@doc raw"""
    x_plus(X :: CStarSurface{<:Union{EE,EP}})

Return the elliptic fixed point $x^+$ of a $\mathbb{C}^*$-surface of type
(e-e) or (e-p). The point is encoded by the index vector of the associated
maximal cone in the ambient toric variety.

"""
@attr x_plus(X :: CStarSurface{<:Union{EE,EP}}) = CStarSurfaces._sigma_plus(X)


@doc raw"""
    x_minus(X :: CStarSurface{<:Union{EE,PE}})

Return the elliptic fixed point $x^-$ of a $\mathbb{C}^*$-surface of type
(e-e) or (p-e). The point is encoded by the index vector of the associated
maximal cone in the ambient toric variety.

"""
@attr x_minus(X :: CStarSurface{<:Union{EE,PE}}) = CStarSurfaces._sigma_minus(X)


@doc raw"""
    elliptic_fixed_points(X :: CStarSurface)

Return the index vectors of the cones associated to the elliptic fixed
points of a $\mathbb{C}^*$-surface.

# Example

```jldoctest
julia> X = cstar_surface([[2,1],[1,1],[2]], [[3,-1],[0,-1],[1]], :ee)
C-star surface of type (e-e)

julia> elliptic_fixed_points(X)
2-element Vector{Vector{Int64}}:
 [1, 3, 5]
 [2, 4, 5]
```

"""
@attr elliptic_fixed_points(X :: CStarSurface{EE}) = [x_plus(X), x_minus(X)]
@attr elliptic_fixed_points(X :: CStarSurface{PE}) = [x_minus(X)]
@attr elliptic_fixed_points(X :: CStarSurface{EP}) = [x_plus(X)]
@attr elliptic_fixed_points(X :: CStarSurface{PP}) = Vector{Int}[]


@doc raw"""
    hyperbolic_fixed_point(X :: CStarSurface, i :: Int, j :: Int)

Return the hyperbolic fixed point $x_{ij}$ of a $\mathbb{C}^*$-surface, where
$0 ≤ i ≤ r$ and $1 ≤ j ≤ n_i - 1$. The point is encoded by the index vector of
the associated maximal cone in the ambient toric variety.

"""
function hyperbolic_fixed_point(X :: CStarSurface, i :: Int, j :: Int)
    r, ns = _r(X), _ns(X)
    @req 0 ≤ i ≤ r "must have 0 ≤ i ≤ r"
    @req 1 ≤ j ≤ ns[i] - 1 "must have 1 ≤ j ≤ ns[i] - 1"
    return _tau(X, i, j)
end


@doc raw"""
    hyperbolic_fixed_points(X :: CStarSurface)   

Return the index vectors of the cones associated to the hyperbolic fixed 
points of a $\mathbb{C}^*$-surface.

"""
@attr hyperbolic_fixed_points(X :: CStarSurface) = 
DoubleVector([[hyperbolic_fixed_point(X, i, j) for j = 1 : _ns(X)[i] - 1] for i = 0 : _r(X)])


@doc raw"""
    parabolic_fixed_point_plus(X :: CStarSurface{<:Union{PE,PP}}, i :: Int)

Return the parabolic fixed point $x_i^+$ of a $\mathbb{C}^*$-surface, where $0
≤ i ≤ r$. The point is encoded by the index vector of the associated maximal
cone in the ambient toric variety.

"""
function parabolic_fixed_point_plus(X :: CStarSurface{<:Union{PE,PP}}, i :: Int)
    r = _r(X)
    @req 0 ≤ i ≤ r "must have 0 ≤ i ≤ r"
    return _tau_plus(X, i)
end


@doc raw"""
    parabolic_fixed_point_minus(X :: CStarSurface{<:Union{EP,PP}}, i :: Int)

Return the parabolic fixed point $x_i^-$ of a $\mathbb{C}^*$-surface, where $0
≤ i ≤ r$. The point is encoded by the index vector of the associated maximal
cone in the ambient toric variety.

"""
function parabolic_fixed_point_minus(X :: CStarSurface{<:Union{EP,PP}}, i :: Int)
    r = _r(X)
    @req 0 ≤ i ≤ r "must have 0 ≤ i ≤ r"
    return _tau_minus(X, i)
end

@doc raw"""
    parabolic_fixed_points(X :: CStarSurface)

Return the index vectors of the cones associated to the possibly singular
parabolic fixed points of a $\mathbb{C}^*$-surface. See also
[`parabolic_fixed_point_curves`](@ref).

"""
@attr parabolic_fixed_points(X :: CStarSurface{EE}) = Vector{Int}[]
@attr parabolic_fixed_points(X :: CStarSurface{PE}) = _taus_plus(X)
@attr parabolic_fixed_points(X :: CStarSurface{EP}) = _taus_minus(X)
@attr parabolic_fixed_points(X :: CStarSurface{PP}) = [_taus_plus(X) ; _taus_minus(X)]


@doc raw"""
    D_plus(X :: CStarSurface{<:Union{PE,PP}})    

Return the parabolic fixed point curve $D^+$ of a $\mathbb{C}^*$-surface of
type (p-e) or (p-p).

"""
@attr D_plus(X :: CStarSurface{PE}) = 
cstar_surface_divisor(X, [repeat([0], n) for n in _ns(X)], 1)
@attr D_plus(X :: CStarSurface{PP}) = 
cstar_surface_divisor(X, [repeat([0], n) for n in _ns(X)], 1, 0)


@doc raw"""
    D_minus(X :: CStarSurface{<:Union{EP,PP}})    

Return the parabolic fixed point curve $D^-$ of a $\mathbb{C}^*$-surface of
type (e-p) or (p-p).

"""
@attr D_minus(X :: CStarSurface{EP}) = 
cstar_surface_divisor(X, [repeat([0], n) for n in _ns(X)], 1)
@attr D_minus(X :: CStarSurface{PP}) = 
cstar_surface_divisor(X, [repeat([0], n) for n in _ns(X)], 0, 1)


@doc raw"""
    parabolic_fixed_point_curves(X :: CStarSurface)   

Return the parabolic fixed point curves of a $\mathbb{C}^*$-surface.

"""
@attr parabolic_fixed_point_curves(X :: CStarSurface{EE}) = CStarSurfaceDivisor{EE}[]
@attr parabolic_fixed_point_curves(X :: CStarSurface{PE}) = [D_plus(X)]
@attr parabolic_fixed_point_curves(X :: CStarSurface{EP}) = [D_minus(X)]
@attr parabolic_fixed_point_curves(X :: CStarSurface{PP}) = [D_plus(X), D_minus(X)]


@doc raw"""
    number_of_parabolic_fixed_point_curves(X :: CStarSurface)

Returns the number of parabolic fixed point curves of a $\mathbb{C}^*$-surface.

"""
@attr number_of_parabolic_fixed_point_curves(X :: CStarSurface) = _m(X)


@doc raw"""
    invariant_divisor(X :: CStarSurface, i :: Int, j :: Int)

Return the $(i,j)$-th invariant divisor $D^{ij}_X$.

"""
function invariant_divisor(X :: CStarSurface, i :: Int, j :: Int)
    r, ns, m = _r(X), _ns(X), _m(X)
    @req 0 ≤ i ≤ r "must have 0 ≤ i ≤ r"
    @req 1 ≤ j ≤ ns[i] "must have 1 ≤ j ≤ ns[i]"
    coeffs = [repeat([0], n) for n in ns]
    coeffs[i][j] = 1
    m == 0 && return cstar_surface_divisor(X, coeffs)
    m == 1 && return cstar_surface_divisor(X, coeffs, 0)
    return cstar_surface_divisor(X, coeffs, 0, 0)
end

_invariant_divisors_core(X :: CStarSurface) = 
DoubleVector([[invariant_divisor(X, i, j) for j = 1 : _ns(X)[i]] for i = 0 : _r(X)])


@doc raw"""
    invariant_divisors(X :: CStarSurface)

Return all invariant divisors $D^{ij}_X, D^{\pm}_X$. The result is given as a
pair with first entry the divisors of the form $D^{ij}$ and second entry the 
divisors of the form $D^{\pm}$.

"""
@attr invariant_divisors(X :: CStarSurface{EE}) = (_invariant_divisors_core(X), CStarSurfaceDivisor{EE}[])
@attr invariant_divisors(X :: CStarSurface{PE}) = (_invariant_divisors_core(X), [D_plus(X)])
@attr invariant_divisors(X :: CStarSurface{EP}) = (_invariant_divisors_core(X), [D_minus(X)])
@attr invariant_divisors(X :: CStarSurface{PP}) = (_invariant_divisors_core(X), [D_plus(X), D_minus(X)])

#################################################
# Cox Ring
#################################################

@doc raw"""
    cox_ring_vars(X :: CStarSurface)

Return the variables in the Cox Ring of the canonical toric ambient of a C-star
surface, following the double index notation. The result
is a tuple, whose first entry is a DoubleVector consisting of the variables
T[i][j] and whose second entry is the Vector of variables [S[1], ... S[m]], 
where `m` is the number of parabolic fixed point curves.

# Example

```jldoctest
julia> X = cstar_surface([[1, 1], [2], [2]], [[-3, -4], [1], [1]], :pe)
C-star surface of type (p-e)

julia> (Ts, Ss) = cox_ring_vars(X);

julia> Ts
3-element DoubleVector{MPolyDecRingElem} with indices ZeroRange(3):
 [T[0][1], T[0][2]]
 [T[1][1]]
 [T[2][1]]

julia> Ss
1-element Vector{MPolyDecRingElem{QQFieldElem, QQMPolyRingElem}}:
 S[1]
```

"""
@attr function cox_ring_vars(X :: CStarSurface)
    r, ns, m = _r(X), _ns(X), _m(X)
    Z = canonical_toric_ambient(X)
    cox_gens = gens(cox_ring(Z))

    Ts = DoubleVector{MPolyDecRingElem}(undef, ns)
    k = 1
    for i = 0 : r, j = 1 : ns[i]
        Ts[i][j] = cox_gens[k]
        k += 1
    end

    Ss = cox_gens[end - (m-1) : end]

    return (Ts,Ss)
end

function _monomial(X :: CStarSurface, i :: Int)
    T = cox_ring_vars(X)[1]
    return prod([T[i][j]^X.l[i][j] for j = 1 : _n(X,i)])
end

_trinomial(X :: CStarSurface, i :: Int) = _monomial(X, i) + _monomial(X, i+1) + _monomial(X, i+2)

@doc raw"""
    cox_ring_relations(X :: CStarSurface)

Return the list of relations in the Cox Ring of a C-star surface. Note that 
these are all trinomials.

# Example

```jldoctest
julia> X = cstar_surface([[1, 1], [2], [2]], [[-3, -4], [1], [1]], :pe)
C-star surface of type (p-e)

julia> cox_ring_relations(X)
1-element Vector{MPolyDecRingElem{QQFieldElem, QQMPolyRingElem}}:
 T[0][1]*T[0][2] + T[1][1]^2 + T[2][1]^2
```
    

"""
@attr cox_ring_relations(X :: CStarSurface) :: 
    Vector{MPolyDecRingElem{QQFieldElem, QQMPolyRingElem}} = 
[_trinomial(X,i) for i = 0 : _r(X) - 2]


@doc raw"""
    canonical_divisor(X :: CStarSurface)

Return the canonical divisor of a C-star surface.

"""
canonical_divisor(X :: CStarSurface{EE}) = 
cstar_surface_divisor(X, [[-1 .+ (_r(X)-1) .* X.l[0]] ; [-one.(X.l[i]) for i = 1 : _r(X)]])

canonical_divisor(X :: CStarSurface{PE}) = 
cstar_surface_divisor(X, [[-1 .+ (_r(X)-1) .* X.l[0]] ; [-one.(X.l[i]) for i = 1 : _r(X)]], -1)

canonical_divisor(X :: CStarSurface{EP}) = 
cstar_surface_divisor(X, [[-1 .+ (_r(X)-1) .* X.l[0]] ; [-one.(X.l[i]) for i = 1 : _r(X)]], -1)

canonical_divisor(X :: CStarSurface{PP}) = 
cstar_surface_divisor(X, [[-1 .+ (_r(X)-1) .* X.l[0]] ; [-one.(X.l[i]) for i = 1 : _r(X)]], -1, -1)


#################################################
# Intersection numbers
#
# We compute intersection numbers following
# Chapter 7 of "Classifying log del Pezzo surfaces
# with torus action" (arXiv:2302.03095)
#################################################

function _mcal(X :: CStarSurface, i :: Int, j :: Int)
    @req 0 ≤ j ≤ _ns(X)[i] "j must be between 0 and n_i"

    j == 0 && return has_x_plus(X) ? -1/m_plus(X) : 0
    j == _ns(X)[i] && return has_x_minus(X) ? -1/m_minus(X) : 0

    ms = sort(slopes(X)[i], rev=true)
    return 1 / (ms[j] - ms[j+1])
end

@attr _mcals(X :: CStarSurface) = ZeroVector([[_mcal(X, i, j) for j = 0 : _ns(X)[i]] for i = 0 : _r(X)])


@doc raw"""
    intersection_matrix(X :: CStarSurface)

Return the matrix of intersection numbers of all restrictions of toric prime
divisors of a C-star surface `X` with each other. The result is a rational `n` x
`n` matrix, where `n = nrays(X)` and the `(i,j)`-th entry is the intersection
number of the toric prime divisors associated to the `i`-th and `j`-th ray
respectively.

# Example

```jldoctest
julia> intersection_matrix(cstar_surface([[3, 1], [3], [2]], [[-2, -1], [1], [1]], :ee))
[1//3   1   2//3   1]
[   1   3      2   3]
[2//3   2   4//3   2]
[   1   3      2   3]
```

"""
@attr function intersection_matrix(X :: CStarSurface)
    r, n, m, ns = _r(X), _n(X), _m(X), _ns(X)

    # The resulting intersection matrix
    IM = zeros(Rational{Int}, n + m, n + m)

    # The entries ls sorted by slope
    ls = ZeroVector(map(i -> X.l[i][sortperm(slopes(X)[i], rev=true)], 0 : r))

    inds = _slope_ordered_ray_indices(X)

    # 1. Intersection numbers of adjacent rays in the leaf cones
    for i = 0 : r
        if has_D_plus(X) 
            IM[_vplus_index(X), inds[i][1]] = 1 // ls[i][1] 
        end

        for j = 1 : ns[i]-1
            IM[inds[i][j], inds[i][j+1]] = _mcal(X, i, j) // (ls[i][j] * ls[i][j+1])
        end

        if has_D_minus(X) 
            IM[inds[i][ns[i]], _vminus_index(X)] = 1 // ls[i][1] 
        end
    end

    # 2. Intersection numbers of top and bottom most rays with each other
    for i = 0 : r, k = i+1 : r
        if has_x_plus(X)
            IM[inds[i][1], inds[k][1]] = ns[i] * ns[k] == 1 ? 
                -(_mcal(X, i, 0) + _mcal(X, i, ns[i])) // (ls[i][1] * ls[k][1]) :
                -_mcal(X, i, 0) // (ls[i][1] * ls[k][1])
        end
        if has_x_minus(X)
            IM[inds[i][ns[i]], inds[k][ns[k]]] = ns[i] * ns[k] == 1 ? 
                -(_mcal(X, i, 0) + _mcal(X, i, ns[i])) // (ls[i][ns[i]] * ls[k][ns[k]]) :
                -_mcal(X, i, ns[i]) // (ls[i][ns[i]] * ls[k][ns[k]])
        end
    end

    # 3. Self intersection numbers
    if has_D_plus(X)
        IM[_vplus_index(X), _vplus_index(X)] = - m_plus(X)
    end
    if has_D_minus(X)
        IM[_vminus_index(X), _vminus_index(X)] = - m_minus(X)
    end
    for i = 0 : r, j = 1 : ns[i]
        IM[inds[i][j], inds[i][j]] = - 1 // ls[i][j]^2 * (_mcal(X, i, j-1) + _mcal(X, i, j))
    end

    # fill in numbers to make the matrix symmetric
    for i = 1 : n+m, j = 1 : n+m
        if IM[i,j] == 0 
            IM[i,j] = IM[j,i]
        end
    end

    return matrix(QQ, IM)

end


#################################################
# Resolution of singularities
#
# The resolution of singularities for C-star surfaces
# is obtained in two steps: In the tropical step,
# we add the rays [0,...,0,1] and [0,...,0,-1] to 
# the fan, if not already present. The second step
# is toric: We perform regular subdivision all cones
# in the fan, which are now all two-dimensional
#################################################

# See Section 9 of "Classifying log del Pezzo surfaces with 
# torus action" (arxiv:2302.03095) for the definition of 
# these numbers
_d_plus(X :: CStarSurface{EE}) = m_plus(X) // _l_plus(X)
_d_plus(X :: CStarSurface{EP}) = m_plus(X) // _l_plus(X)
_d_plus(X :: CStarSurface{PE}) = 1
_d_plus(X :: CStarSurface{PP}) = 1

_d_minus(X :: CStarSurface{EE}) = m_minus(X) // _l_minus(X)
_d_minus(X :: CStarSurface{EP}) = 1
_d_minus(X :: CStarSurface{PE}) = m_minus(X) // _l_minus(X)
_d_minus(X :: CStarSurface{PP}) = 1


@doc raw"""
    canonical_resolution(X :: CStarSurface)

Return the canonical resolution of singularities of a C-star surface surface
`X`. The result is a triple `(Y, ex_div, discr)` where `Y` is the smooth C-star
surface in the resolution of singularities of `X`, `ex_div` contains the
exceptional divisors in the resolution and `discrepancies` contains their
discrepancies. `ex_rays` and `discr` are both dictionaries indexed by the fixed
points of `X`, i.e. `ex_div[x]` contains those exceptional divisors lying over
the fixed point `x`.

# Example

Resolution of singularities of the $E_6$ singular cubic surface.

```jldoctest
julia> X = cstar_surface([[3, 1], [3], [2]], [[-2, -1], [1], [1]], :ee)
C-star surface of type (e-e)

julia> (Y, ex_div, discr) = canonical_resolution(X);

julia> gen_matrix(Y)
[-3   -1   -2   -1   3   2   1   1   0   0   0   0    0]
[-3   -1   -2   -1   0   0   0   0   2   1   1   0    0]
[-2   -1   -1    0   1   1   1   0   1   1   0   1   -1]

julia> map(E -> E * E, ex_div[x_plus(X)])
6-element Vector{QQFieldElem}:
 -2
 -2
 -2
 -2
 -2
 -2

julia> discr[x_plus(X)]
6-element Vector{Rational{Int64}}:
 0//1
 0//1
 0//1
 0//1
 0//1
 0//1

```

"""
@attr function canonical_resolution(X :: CStarSurface)
    ns, r = _ns(X), _r(X) 
    l, d = _slope_ordered_l(X), _slope_ordered_d(X)

    discrepancies = Dict{Vector{Int}, Vector{Rational{Int}}}()
    ex_div_indices = Dict{Vector{Int}, Vector{Tuple{Int, Int}}}()

    new_l, new_d = deepcopy(X.l), deepcopy(X.d)

    # Resolve hyperbolic fixed points $x_{ij}$
    for i = 0 : r, j = 1 : ns[i] - 1
        x = hyperbolic_fixed_point(X, i, j)

        v1, v2 = [l[i][j], d[i][j]], [l[i][j+1], d[i][j+1]]
        new_rays, discrepancies[x] = toric_affine_surface_resolution(v1, v2)
        ex_div_indices[x] = [(i, length(new_l[i]) + j) for j = 1 : length(new_rays)]

        append!(new_l[i], map(first, new_rays))
        append!(new_d[i], map(last, new_rays))
    end

    if has_x_plus(X)
        # Resolve elliptic fixed point $x^+$
        x = x_plus(X)
        discrepancies[x], ex_div_indices[x] = [], []
        for i = 0 : r
            v = [first(l[i]), first(d[i])]
            new_rays, new_discr = toric_affine_surface_resolution(v, [0, _d_plus(X)])
            append!(discrepancies[x], new_discr)
            append!(ex_div_indices[x], [(i, length(new_l[i]) + j) for j = 1 : length(new_rays)])
            append!(new_l[i], map(first, new_rays))
            append!(new_d[i], map(last, new_rays))
        end
    else
        # Resolve parabolic fixed points $x^+_i$
        for i = 0 : r
            x = parabolic_fixed_point_plus(X, i)
            v = [first(l[i]), first(d[i])]
            new_rays, discrepancies[x] = toric_affine_surface_resolution(v, [0, _d_plus(X)])
            ex_div_indices[x] = [(i, length(new_l[i]) + j) for j = 1 : length(new_rays)]

            append!(new_l[i], map(first, new_rays))
            append!(new_d[i], map(last, new_rays))
        end
    end

    if has_x_minus(X)
        # Resolve elliptic fixed point $x^-$
        x = x_minus(X)
        discrepancies[x], ex_div_indices[x] = [], []
        for i = 0 : r
            v = [last(l[i]), last(d[i])]
            new_rays, new_discr = toric_affine_surface_resolution(v, [0, -_d_minus(X)])
            append!(discrepancies[x], new_discr)
            append!(ex_div_indices[x], [(i, length(new_l[i]) + j) for j = 1 : length(new_rays)])
            append!(new_l[i], map(first, new_rays))
            append!(new_d[i], map(last, new_rays))
        end
    else
        # Resolve parabolic fixed points $x^+_i$
        for i = 0 : r
            x = parabolic_fixed_point_minus(X, i)
            v = [last(l[i]), last(d[i])]
            new_rays, discrepancies[x] = toric_affine_surface_resolution(v, [0, -d_minus(X)])
            ex_div_indices[x] = [(i, length(new_l[i]) + j) for j = 1 : length(new_rays)]

            append!(new_l[i], map(first, new_rays))
            append!(new_d[i], map(last, new_rays))
        end
    end

    Y = cstar_surface(new_l, new_d, :pp)

    ex_div = Dict{Vector{Int}, Vector{CStarSurfaceDivisor}}([c => [invariant_divisor(Y, ij...) for ij in inds] for (c, inds) in ex_div_indices]) 

    if has_x_plus(X)
        push!(ex_div[x_plus(X)], D_plus(Y))
        push!(discrepancies[x_plus(X)], _l_plus(X) // m_plus(X) - 1)
    end

    if has_x_minus(X)
        push!(ex_div[x_minus(X)], D_minus(Y))
        push!(discrepancies[x_minus(X)], _l_minus(X) // m_minus(X) - 1)
    end
    
    return (Y, ex_div, discrepancies)

end


@doc raw"""
    minimal_resolution(X :: CStarSurface)

Return the minimal resolution of singularities of a C-star surface surface `X`.
The minimal resolution is obtained by contracting all (-1)-curves of the
canonical resolution. The result is a triple `(Y, ex_div, discr)` where `Y` is
the smooth C-star surface in the resolution of singularities of `X`, `ex_div`
contains the exceptional divisors in the resolution and `discrepancies`
contains their discrepancies. `ex_rays` and `discr` are both dictionaries
indexed by the fixed points of `X`, i.e. `ex_div[x]` contains those exceptional
divisors lying over the fixed point `x`.

# Example

Resolution of singularities of the $E_6$ singular cubic surface.

```jldoctest
julia> X = cstar_surface([[3, 1], [3], [2]], [[-2, -1], [1], [1]], :ee)
C-star surface of type (e-e)

julia> (Y, ex_div, discr) = minimal_resolution(X);

julia> gen_matrix(Y)
[-3   -1   -2   -1   3   2   1   0   0   0]
[-3   -1   -2   -1   0   0   0   2   1   0]
[-2   -1   -1    0   1   1   1   1   1   1]

```

"""
@attr function minimal_resolution(X :: CStarSurface)
    (Y, ex_div, discrepancies) = deepcopy(canonical_resolution(X))

    contractible_curves = [(x, k, divs[k]) 
        for (x, divs) in ex_div for k = 1 : length(divs) 
        if divs[k] * divs[k] == -1]

    while !isempty(contractible_curves)
        x, k, d = first(contractible_curves)
        Y = contract_prime_divisor(d)
        deleteat!(ex_div[x], k)
        deleteat!(discrepancies[x], k)

        # adjust the coefficients of the remaining exceptional divisors
        d_case, inds = is_prime_with_double_indices(d)
        m = number_of_parabolic_fixed_point_curves(Y)
        for (y, divs) in ex_div, l = 1 : length(divs)
            if d_case == :D_ij
                i, j = inds
                new_coeffs = deleteat!(double_coefficients(divs[l]), i, j)
                last_coeffs = coefficients(divs[l])[end-m+1 : end]
                new_d = cstar_surface_divisor(Y, new_coeffs, last_coeffs...)
            else
                k = inds
                new_coeffs = deleteat!(coefficients(divs[l]), k)
                new_d = cstar_surface_divisor(Y, new_coeffs)
            end
            ex_div[y][l] = new_d
        end

        # compute the new contractible curves
        contractible_curves = [(x, k, divs[k]) 
            for (x, divs) in ex_div for k = 1 : length(divs) 
            if divs[k] * divs[k] == -1]
    end

    return (Y, ex_div, discrepancies)

end





#################################################
# Kaehler Einstein metric
#################################################

@doc raw"""
    is_special_index(X :: CStarSurface, k :: Int)

Check whether a given index `0 ≤ k ≤ r` is special in the sense of 
Definition 5.2/Proposition 5.3 of [HaHaSu23](@cite), i.e the special
fiber of the toric degeneration $\psi_k : \mathcal{X}_k \to \mathbb{C}$
is a normal toric variety.

# Example

Example 6.4 from [HaHaSu23](@cite).

```jldoctest
julia> X = cstar_surface([[2,1],[1,1],[2]], [[3,-1],[0,-1],[1]], :ee)
C-star surface of type (e-e)

julia> is_special_index(X,0)
true
```

"""
function is_special_index(X :: CStarSurface, k :: Int)
    r, ns, n, m, rayinds = _r(X), _ns(X), _n(X), _m(X), _ray_indices(X)
    Q0 = degree_matrix_free_part(X)
    is = [i for i = 0 : r if i ≠ k]

    # The set of all tuples (j_i)_{i ≠ k} such that at l_i > 1 for
    # at least two distinct i ≠ k.
    Js = [last.(J) for J in 
          Iterators.product([zip(X.l[i], 1:ns[i]) for i in is]...)
          if length(filter(l -> l > 1, first.(J))) > 1]

    isempty(Js) && return true

    # convert to single index notation
    Js = map(J -> [rayinds[is[i]][J[i]] for i = 1 : r], Js)
    # take the complement for each list of indices
    Js = map(J -> [k for k in 1 : n + m if k ∉ J], Js) 
    cones = map(J -> positive_hull(transpose(Q0[:,J])), Js)

    α = QQ.(free_part(anticanonical_divisor_class(X)))
    return all(c -> !Polymake.polytope.contains_in_interior(pm_object(c), α), cones)
end


@doc raw"""
    special_indices(X :: CStarSurface)

Returns the subset of indices in `0 : r` that are special in the sense
of Definition 5.2/Proposition 5.3 of [HaHaSu23](@cite), i.e. those where
the special fiber of the toric degeneration $\psi_k : \mathcal{X}_k \to
\mathbb{C}$ is a normal toric variety.

# Example

Example 6.4 from [HaHaSu23](@cite).

```jldoctest
julia> X = cstar_surface([[2,1],[1,1],[2]], [[3,-1],[0,-1],[1]], :ee)
C-star surface of type (e-e)

julia> special_indices(X)
2-element Vector{Int64}:
 0
 2

```

"""
@attr special_indices(X :: CStarSurface) = filter(i -> is_special_index(X, i), 0 : _r(X))


function _antitrop_transform(k :: Int, v)
    sign = k == 0 ? 1 : -1
    if k == 0 
        k += 1
    end
    return [v[end-1], v[end], sign*v[k]]
end

@doc raw"""
    moment_polytope(X :: CStarSurface, k :: Int)

Returns the moment polytope for a given `k = 0, ..., r`, as constructed 
in Construction 5.5 of [HaHaSu23](@cite).

# Example

Example 6.4 from [HaHaSu23](@cite).

```jldoctest
julia> X = cstar_surface([[2,1],[1,1],[2]], [[3,-1],[0,-1],[1]], :ee)
C-star surface of type (e-e)

julia> vertices(moment_polytope(X, 0))
4-element SubObjectIterator{PointVector{QQFieldElem}}:
 [1, 0]
 [0, -1//2]
 [-1//2, -1//4]
 [1//5, 4//5]

```

"""
moment_polytope(X :: CStarSurface, k :: Int) = moment_polytopes(X)[k]


@doc raw"""
    moment_polytopes(X :: CStarSurface)

Return the moment polytopes for all `k = 0, ..., r`, as constructed 
in Construction 5.5 of [HaHaSu23](@cite).

# Example

Example 6.4 from [HaHaSu23](@cite).

```jldoctest
julia> X = cstar_surface([[2,1],[1,1],[2]], [[3,-1],[0,-1],[1]], :ee)
C-star surface of type (e-e)

julia> map(vertices, moment_polytopes(X))
3-element ZeroVector{SubObjectIterator{PointVector{QQFieldElem}}} with indices ZeroRange(3):
 [[1, 0], [0, -1//2], [-1//2, -1//4], [1//5, 4//5]]
 [[1, 0], [0, 1], [-1//2, 1], [1//5, -2//5]]
 [[1//5, -3//5], [1, 1], [-1//2, 1//4], [0, -1//2]]

```

"""
@attr function moment_polytopes(X :: CStarSurface)

    r = _r(X)
    vs = rays(X)
    α = coefficients(anticanonical_divisor(X))
    σ0 = positive_hull([[vs[i] ; α[i]] for i = 1 : length(vs)], non_redundant = true)

    result = ZeroVector{Polyhedron{QQFieldElem}}(undef, r+1)
    for k = 0 : r
        V_gen = [[basis_vector(r, k) ; [0,0]], basis_vector(r+2, r+1), basis_vector(r+2, r+2)]
        V = positive_hull(V_gen[1], V_gen, non_redundant = true)
        σ = intersect(σ0, V)

        τ = positive_hull(map(v -> _antitrop_transform(k, v), rays(σ)), non_redundant = true)
        ω = polarize(τ)

        C = convex_hull([[v[1] // v[2], v[3] // v[2]] for v in rays(ω)], non_redundant = true)

        if k ∈ special_indices(X)
            u = interior_lattice_points(C)[1]
            result[k] = convex_hull([v - u for v in vertices(C)], non_redundant = true)
        else
            result[k] = C
        end
    end

    return result

end

@doc raw"""
    admits_kaehler_einstein_metric(X :: CStarSurface)

Checks whether a C-star surface admits a Kaehler-Einstein metric.

# Example

```jldoctest
julia> admits_kaehler_einstein_metric(cstar_surface([[1,1], [4], [4]], [[-1,-2], [3], [3]], :ee))
true

```

"""
@attr admits_kaehler_einstein_metric(X :: CStarSurface) =
all(v -> v[1] == 0, map(i -> centroid(moment_polytope(X,i)), 0 : _r(X))) &&
all(v -> v[2] > 0, map(i -> centroid(moment_polytope(X,i)), special_indices(X)))



#################################################
# Printing
#################################################


Base.show(io :: IO, X :: CStarSurface{EE}) = print(io, "C-star surface of type (e-e)")
Base.show(io :: IO, X :: CStarSurface{PE}) = print(io, "C-star surface of type (p-e)")
Base.show(io :: IO, X :: CStarSurface{EP}) = print(io, "C-star surface of type (e-p)")
Base.show(io :: IO, X :: CStarSurface{PP}) = print(io, "C-star surface of type (p-p)")

