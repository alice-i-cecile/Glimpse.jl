# WATCHOUT FOR NOTHING
data_id(e::Entity, id::Int) = getfirst(x -> x.comp_id == id, e.data_ids).data_id

# All entity Assemblages go here

assemble_sphere(position::Point3f0,
	   velocity::Vec3f0,
	   color   ::RGBA{Float32},
       radius  ::Float32,
       specint ::Float32,
       specpow ::Float32,
       ::Type{RP}) where {RP <: RenderPassKind} = (Spatial(position, velocity),
		                                           PolygonGeometry(Sphere(Point3f0(0.0), 1.0f0)),
		                                           Upload{RP}(false, true),
		                                           Material(specint, specpow, color),
		                                           UniformColor(color),
		                                           Shape(radius))

assemble_camera3d(eyepos  ::Point3f0,
				  velocity::Vec3f0,
				  args...) = (Spatial(eyepos, velocity),
				              Camera3D(eyepos, args...))

