import GLAbstraction: FrameBuffer, VertexArray, Buffer, Program
import GLAbstraction: textureformat_from_type_sym, getfirst, gluniform, clear!

#----------------GLAbstraction-------------------------#
default_framebuffer(fb_size) = FrameBuffer(fb_size, DepthStencil{GLAbstraction.Float24, N0f8}, RGBA{N0f8}, Vec{2, GLushort}, RGBA{N0f8})
clear!(fbo::FrameBuffer, color::RGBA) = clear!(fbo, (color.r, color.g, color.b, color.alpha))

const fullscreen_pos = [Vec3f0(-1, 1, 0), Vec3f0(-1, -1, 0),
                        Vec3f0(1, 1, 0) , Vec3f0(1, -1, 0)]
const fullscreen_uv = [Vec2f0(0, 1), Vec2f0(0, 0),
                       Vec2f0(1, 1), Vec2f0(1, 0)]

#This is to be used with composite program
function compositing_vertexarray(program::Program)
    uv       = attribute_location(program, :uv)
    position = attribute_location(program, :position)
    VertexArray([Buffer(fullscreen_pos) => position,
                 Buffer(fullscreen_uv) => uv],
                nothing;
                facelength=5)
end
fullscreen_vertexarray() = VertexArray([GLint(0) => Buffer(fullscreen_pos),
                                        GLint(1) => Buffer(fullscreen_uv)],
                                       5)

@inline function sleep_pessimistic(sleep_time)
    st = convert(Float64, sleep_time) - 0.002
    start_time = time()
    while (time() - start_time) < st
        sleep(0.001) # sleep for the minimal amount of time
    end
end

#REVIEW: not used
function glenum2julia(x::UInt32)
    x == GL_FLOAT      && return f32
    x == GL_FLOAT_VEC3 && return Vec3f0
    x == GL_FLOAT_VEC4 && return Vec4f0
    x == GL_FLOAT_MAT2 && return Mat2f0
    x == GL_FLOAT_MAT3 && return Mat3f0
    x == GL_FLOAT_MAT4 && return Mat4f0

    x == GL_DOUBLE      && return f64
    x == GL_DOUBLE_VEC3 && return Vec3{f64}
    x == GL_DOUBLE_VEC4 && return Vec4{f64}
    x == GL_DOUBLE_MAT2 && return Mat2{f64}
    x == GL_DOUBLE_MAT3 && return Mat3{f64}
    x == GL_DOUBLE_MAT4 && return Mat4{f64}

    x == GL_INT       && return i32
    x == GL_INT_VEC2  && return Vec2{i32}
    x == GL_INT_VEC3  && return Vec3{i32}
    x == GL_INT_VEC4  && return Vec4{i32}

    x == GL_UNSIGNED_INT        && return u32
    x == GL_UNSIGNED_INT_VEC2   && return Vec2{u32}
    x == GL_UNSIGNED_INT_VEC3   && return Vec3{u32}
    x == GL_UNSIGNED_INT_VEC4   && return Vec4{u32}
end

function mergepop!(d1, d2)
    t = SymAnyDict()

    d = isempty(d2) ? SymAnyDict() : Dict(d2)
    for (key, val) in d1
        t[key] = pop!(d, key, val)
    end
    d2 = [d...]
    return t
end

#this stuff is here because of world age stuff I think
function gluniform(location::Integer, x::Mat4{Float32})
    glUniformMatrix4fv(location, 1, GL_FALSE, reinterpret(Float32,[x]))
end

function uniformfunc(typ::DataType, dims::Tuple{Int})
    Symbol(string("glUniform", first(dims), GLAbstraction.opengl_postfix(typ)))
end
function uniformfunc(typ::DataType, dims::Tuple{Int, Int})
    M, N = dims
    Symbol(string("glUniformMatrix", M == N ? "$M" : "$(M)x$(N)", opengl_postfix(typ)))
end

function gluniform(location::Integer, x::FSA) where FSA
    GLAbstraction.glasserteltype(FSA)
    xref = [x]
    gluniform(location, xref)
end

Base.ndims(::Type{<:Colorant}) = 1
Base.size(::Type{<:Number}) = 1

@generated function gluniform(location::Integer, x::Vector{FSA}) where FSA
    GLAbstraction.glasserteltype(eltype(FSA))
    func = uniformfunc(eltype(FSA), size(FSA))
    callexpr = if ndims(FSA) == 2
        :($func(location, length(x), GL_FALSE, xref))
    else
        :($func(location, length(x), xref))
    end
    quote
        xref = reinterpret(eltype(FSA), x)
        $callexpr
    end
end

gluniform(location::Integer, x::Int) = gluniform(location, GLint(x))
gluniform(location::Integer, x::UInt) = gluniform(location, GLuint(x))
gluniform(location::Integer, x::AbstractFloat) = gluniform(location, GLfloat(x))

#----------------- Composite OpenGL Calls -------------#
const none = !any

function glEnableDepth(f::Function)
    glEnable(GL_DEPTH_TEST)
    if f == all
        glDepthFunc(GL_ALWAYS)
    elseif f == none
        glDepthFunc(GL_NEVER)
    elseif f == <
        glDepthFunc(GL_LESS)
    elseif f == <=
        glDepthFunc(GL_LEQUAL)
    elseif f == >
        glDepthFunc(GL_GREATER)
    elseif f == >=
        glDepthFunc(GL_GEQUAL)
    elseif f == ==
        glDepthFunc(GL_EQUAL)
    elseif f == !=
        glDepthFunc(GL_NOTEQUAL)
    else
        @error "Function $f has no OpenGL DepthFunc equivalent."
    end
end

glDisableDepth() = glDisable(GL_DEPTH_TEST)

function glEnableCullFace(s::Symbol)
    glEnable(GL_CULL_FACE)
    if s == :front
        glCullFace(GL_FRONT)
    elseif s == :back
        glCullFace(GL_BACK)
    elseif s == :front_back
        glCullFace(GL_FRONT_AND_BACK)
    else
        @error "Symbol $s has no OpenGL CullFace equivalent."
    end
end

glDisableCullFace() = glDisable(GL_CULL_FACE)

#----------------GeometryTypes-------------------------#

# const INSTANCED_MESHES = Dict{Symbol, BasicMesh}()
#
# struct InstancedAttributeMesh{D, T, FD, FT, AT <: NamedTuple} <: AbstractGlimpseMesh
#     basic      ::BasicMesh{D, T, FD, FT}
#     attributes ::Vector{AT}
# end
#
# function InstancedAttributeMesh(basic_symbol::Symbol, attributes::NamedTuple)
#     if !haskey(INSTANCED_MESHES, basic_symbol)
#         error("No instanced mesh `$basic_symbol` found.")
#     end
#     return InstancedAttributeMesh(INSTANCED_MESHES[basic_symbol], basic_symbol, attributes)
# end
#
# InstancedAttributeMesh(basic_symbol::Symbol, attributes::NamedTuple, geometry, args...) =
#     InstancedAttributeMesh(basic_symbol, attributes, BasicMesh(geometry, args...))
#
# InstancedAttributeMesh(basic_symbol::Symbol, geometry, args...; attributes...) =
#     InstancedAttributeMesh(basic_symbol, NamedTuple{keys(attributes)}(values(attributes)), BasicMesh(geometry, args...))
#
# basicmesh(mesh::InstancedAttributeMesh) = mesh.basic


#----------------------GLFW----------------------------#
destroy_current_context() = GLFW.DestroyWindow(GLFW.GetCurrentContext())
