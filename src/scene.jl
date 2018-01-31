import GLAbstraction: free!

mutable struct Scene
    name::Symbol
    renderables::Vector{<:Renderable}
    camera::Camera
end
Scene() = Scene(:GLider, Renderable[], Camera{pixel}())
function Scene(name::Symbol, renderables::Vector{<:Renderable})
    dim = 2
    for r in renderables
        dim = eltype(r)[1] > dim ? eltype(r)[1] : dim
    end
    area = Area(0, 0, standard_screen_resolution()...)
    if dim == 2
        camera = Camera{pixel}() 
    elseif dim == 3
        camera = Camera{perspective}() 
    end
    return Scene(name, renderables, camera)
end

function free!(sc::Scene)
    for r in sc.renderables
        free!(r)
    end
end

add!(sc::Scene, renderable::Renderable) = push!(sc.renderables, renderable)
function set!(sc::Scene, camera::Camera)
    sc.camera = camera
end
