# import GeometryTypes: Vec, Mat

abstract type InteractiveSystem <: System end

struct CameraOperator <: InteractiveSystem end

Overseer.requested_components(::CameraOperator) = (Spatial, Camera3D, Canvas)

function Overseer.update(::CameraOperator, m::AbstractLedger)
	spatial = m[Spatial]
	camera = m[Camera3D]
	canvas_comp=m[Canvas]
	canvas = canvas_comp[1]

    mouse = singleton(m, Mouse)
	keyboard = singleton(m, Keyboard)


	x, y = mouse.x, mouse.y
	mouse_button         = canvas.mouse_buttons
    w, h                 = size(canvas)

    scroll_dx, scroll_dy = mouse.dscroll
    dx      = mouse.dx
    dy      = mouse.dy

	@inbounds for e in @entities_in(spatial && camera)
    	spat = spatial[e]
    	cam  = camera[e]
		new_pos = Point3f0(spat.position)
		#world orientation/mouse stuff
	    new_lookat    = cam.lookat
	    if pressed(mouse) && !(keyboard.button ∈ CTRL_KEYS && pressed(keyboard))
	        if mouse.button == GLFW.MOUSE_BUTTON_1 #rotation
			    trans1  = translmat(-cam.lookat)
			    rot1    = rotate(dy * cam.rotation_speed, -cam.right)
			    rot2    = rotate(-dx * cam.rotation_speed, cam.up)
			    trans2  = translmat(cam.lookat)
			    mat_    = trans2 * rot2 * rot1 * trans1
			    new_pos = Point3f0((mat_ * Vec4f0(new_pos..., 1.0f0))[1:3])

	        elseif mouse.button == GLFW.MOUSE_BUTTON_2 #panning
				rt          = cam.right * dx * cam.translation_speed / 2
				ut          = -cam.up   * dy * cam.translation_speed / 2
				new_lookat -= rt + ut
				new_pos    -= rt + ut
	        end
        end

		#keyboard stuff
	    if pressed(keyboard)
	        if keyboard.button in WASD_KEYS
	            new_pos, new_lookat = wasd_event(new_pos, cam, keyboard)
	        # elseif keyboard_button[1] == Int(KEY_Q)
	            # cam.fov -= 1
	            # cam.proj = projmatpersp( Area(0,0,standard_screen_resolution()...), cam.fov,0.1f0, 300f0)
	        end
	    end

	    #resize stuff
	    new_proj = projmatpersp(w, h, cam.fov, cam.near, cam.far) #TODO only perspective
	    #scroll stuff no dxp
	    new_forward   = forward(new_pos, new_lookat)
	    new_pos      += Point3f0(new_forward * scroll_dy * cam.translation_speed*5)

		# update_viewmat
		u_forward    = normalize(new_forward)
	    new_right    = unitright(u_forward, cam.up)
	    new_up       = unitup(u_forward, new_right)
	    new_view     = lookatmat(new_pos, new_lookat, new_up)
	    new_projview = new_proj * new_view
		spatial[e] = Spatial(new_pos, spat.velocity)
		camera[e]  = Camera3D(new_lookat, new_up, new_right, cam.fov, cam.near, cam.far, new_view,
		                            new_proj, new_projview, cam.rotation_speed, cam.translation_speed)
    end
end

unitforward(position, lookat) = normalize(forward(position, lookat))
unitright(forward, up)        = normalize(right(forward, up))
unitup(forward, right)        = normalize(up(forward, right))

forward(position, lookat) = Vec3f0(lookat - position)
right(forward, up)        = cross(forward, up)
up(forward, right)        = cross(right, forward)



#maybe it would be better to make the eyepos up etc vectors already vec4 but ok
function wasd_event(position::Point3f0, cam::Camera3D, keyboard)
    #ok this is a bit hacky but fine
    # origlen = norm(position)
    button = keyboard.button
    new_lookat = cam.lookat
    if button == GLFW.KEY_A
	    move        = Point3f0(cam.translation_speed * 5 * cam.right)
        #the world needs to move in the opposite direction
        position   -= move
        new_lookat -= move
	end
    if button == GLFW.KEY_D
	    move        = Point3f0(cam.translation_speed * 5 * cam.right)
        position   += move
        new_lookat += move
	end
    if button == GLFW.KEY_W
	    move = Point3f0(unitforward(position, cam.lookat) * 5 * cam.translation_speed)
        position   += move
        new_lookat += move

	end
    if button == GLFW.KEY_S

	    move = Point3f0(unitforward(position, cam.lookat) * 5 * cam.translation_speed)
        position   -= move
        new_lookat -= move

    end
    return position, new_lookat
end
