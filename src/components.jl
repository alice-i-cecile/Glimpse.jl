import Base.Iterators: Cycle

@component struct DioEntity end

#TODO get rid of this in favor of a correct iterator
function shared_entities(c::SharedComponent{T}, dat::T) where T
	ids = Int[]
	id = findfirst(x -> x == dat, c.shared)
	return findall(x -> x == id, data(c))
end

# DEFAULT COMPONENTS
abstract type Vao <: ComponentData end

macro vao(name)
    esc(quote
        @component_with_kw mutable struct $name <: Vao
        	vertexarray::VertexArray
        	visible    ::Bool = true
    	end
    	$name(v::VertexArray) = $name(vertexarray=v)
	end)
end

macro instanced_vao(name)
    esc(quote
        @shared_component_with_kw mutable struct $name <: Vao
        	vertexarray::VertexArray
        	visible    ::Bool = true
    	end
    	$name(v::VertexArray) = $name(vertexarray=v)
	end)
end

Base.length(vao::Vao) = length(vao.vertexarray)
GLA.bind(vao::Vao) = GLA.bind(vao.vertexarray)

GLA.draw(vao::Vao) = GLA.draw(vao.vertexarray)

GLA.upload!(vao::Vao; kwargs...) = GLA.upload!(vao.vertexarray; kwargs...) 

# NON rendering Components
@component struct Dynamic  end
@component_with_kw struct Spatial 
	position::Point3f0 = zero(Point3f0)
	velocity::Vec3f0   = zero(Vec3f0)
end

@component_with_kw struct Shape 
	scale::Float32 = 1f0
	# orientation::Quaternionf0 = 
end

@component_with_kw struct ModelMat 
	modelmat::Mat4f0 = Eye4f0()
end

@component_with_kw struct Material 
	specpow ::Float32 = 0.8f0
	specint ::Float32 = 0.8f0
end

@component_with_kw struct PointLight 
    diffuse ::Float32  = 0.5f0
    specular::Float32  = 0.5f0
    ambient ::Float32  = 0.5f0
end

@component struct DirectionLight 
	direction::Vec3f0
    diffuse  ::Float32
    specular ::Float32
    ambient  ::Float32
end

const X_AXIS = Vec3f0(1.0f0, 0.0  , 0.0)
const Y_AXIS = Vec3f0(0.0,   1.0f0, 0.0)
const Z_AXIS = Vec3f0(0.0,   0.0  , 1.0f0)

@component_with_kw struct Camera3D 
    lookat ::Vec3f0             = zero(Vec3f0)
    up     ::Vec3f0             = Z_AXIS 
    right  ::Vec3f0             = X_AXIS 
    fov    ::Float32            = 42f0
    near   ::Float32            = 0.1f0
    far    ::Float32            = 3000f0
    view   ::Mat4f0
    proj        ::Mat4f0
    projview    ::Mat4f0
    rotation_speed    ::Float32 = 0.001f0
    translation_speed ::Float32 = 0.02f0
end

function Camera3D(width_pixels::Integer, height_pixels::Integer; eyepos = -10*Y_AXIS,
													     lookat = zero(Vec3f0),
                                                         up     = Z_AXIS,
                                                         right  = X_AXIS,
                                                         near   = 0.1f0,
                                                         far    = 3000f0,
                                                         fov    = 42f0)
    up    = normalizeperp(lookat - eyepos, up)
    right = normalize(cross(lookat - eyepos, up))

    viewm = lookatmat(eyepos, lookat, up)
    projm = projmatpersp(width_pixels, height_pixels, near, far, fov)
    return Camera3D(lookat=lookat, up=up, right=right, fov=fov, near=near, far=far, view=viewm, proj=projm, projview=projm * viewm) 
end

function Camera3D(old_cam::Camera3D, new_pos::Point3f0, new_lookat::Point3f0, u_forward::Vec3f0=unitforward(new_pos, new_lookat))
	new_right    = unitright(u_forward, old_cam.up)
	new_up       = unitup(u_forward, new_right)
	new_view     = lookatmat(new_pos, new_lookat, new_up)
	new_projview = old_cam.proj * new_view

    return Camera3D(new_lookat, new_up, new_right, old_cam.fov, old_cam.near, old_cam.far, new_view,
	                            old_cam.proj, new_projview, old_cam.rotation_speed, old_cam.translation_speed,
	                            old_cam.mouse_pos, old_cam.scroll_dx, old_cam.scroll_dy)
end

# Meshing and the like
@shared_component struct Mesh 
	mesh
end

@component struct Alpha
    α::Float32
end

abstract type Color <: ComponentData end

# one color, will be put as a uniform in the shader
@component_with_kw struct UniformColor <: Color 
	color::RGBf0 = DEFAULT_COLOR 
end

# vector of colors, either supplied manually or filled in by mesher
@component struct BufferColor <: Color
	color::Vector{RGBAf0}
end
	
# color function, mesher uses it to throw in points and get out colors
#TODO super slow
@component struct FunctionColor <: Color 
	color::Function
end

@component struct DensityColor <: Color 
	color::Array{RGBAf0, 3}
end

# Cycle, mesher uses it to iterate over together with points
@component struct CycledColor <: Color
	color::Cycle{Union{RGBAf0, Vector{RGBAf0}}}
end

@component struct IDColor <: Color
    color::RGBf0
end

@shared_component struct Grid 
	points::Array{Point3f0, 3}
end

abstract type Geometry <: ComponentData end

@component struct PolygonGeometry <: Geometry #spheres and the like
	geometry 
end

@component struct FileGeometry <: Geometry #.obj files
	geometry::String 
end

@component struct FunctionGeometry <: Geometry
	geometry::Function
	iso     ::Float32
end

@component struct DensityGeometry <: Geometry
	geometry::Array{Float32, 3}
	iso     ::Float32
end

@component struct VectorGeometry <: Geometry
	geometry::Vector{Point3f0}
end

@component struct LineGeometry <: Geometry
    points::Vector{Point3f0}
    function LineGeometry(points::Vector{Point3f0})
        if length(points) < 4
            insert!(points, 1, points[2] + 1.001*(points[1] - points[2]))
        end
        if length(points) < 4
            push!(points, points[end-1] + 1.001*(points[end] - points[end-1]))
        end
        return new(points)
    end
end

@component_with_kw struct LineOptions 
	thickness::Float32 = 2.0f0
	miter    ::Float32 = 0.6f0
end

@component_with_kw struct Text 
	str      ::String = "test"
	font_size::Float64  = 1
	font     = AP.defaultfont()
	align    ::Symbol = :right
	offset   ::Vec3f0= zero(Vec3f0)
end
