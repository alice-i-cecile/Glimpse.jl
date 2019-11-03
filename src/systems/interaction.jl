const WASD_KEYS  = (GLFW.KEY_W, GLFW.KEY_A, GLFW.KEY_S, GLFW.KEY_D)
const SHIFT_KEYS = (GLFW.KEY_LEFT_SHIFT, GLFW.KEY_RIGHT_SHIFT)
const CTRL_KEYS  = (GLFW.KEY_LEFT_CONTROL, GLFW.KEY_RIGHT_CONTROL)

@component mutable struct Mouse
    x::Float32
    y::Float32
    dx::Float32
    dy::Float32
    scroll::NTuple{2, Float32}
    dscroll::NTuple{2, Float32}
    button::GLFW.MouseButton
    action::GLFW.Action
end

@component mutable struct Keyboard
    button::GLFW.Key
    modifiers::Int
    action::GLFW.Action
end

struct EventPoller <: System end

Overseer.requested_components(::EventPoller) = (Mouse, Keyboard, Canvas)

function Overseer.update(::EventPoller, m::AbstractLedger)
    c = singleton(m, Canvas)
    mouse = singleton(m, Mouse)
    keyboard = singleton(m, Keyboard)
    pollevents(c)

	x, y = c.cursor_position

	mouse_button         = c.mouse_buttons
	keyboard_button      = c.keyboard_buttons

	mouse.dx = x - mouse.x
	mouse.dy = y - mouse.y
	mouse.x  = x
	mouse.y  = y
	mouse.button = mouse_button[1]
	mouse.action = mouse_button[2] 
	mouse.dscroll = c.scroll .- mouse.scroll
	mouse.scroll  = c.scroll

	keyboard.button    = keyboard_button[1]
	keyboard.action   = keyboard_button[3]
	keyboard.modifiers = keyboard_button[4]
end

pressed(m::Mouse)     = m.action ∈ (GLFW.PRESS, GLFW.REPEAT)
pressed(k::Keyboard)  = k.action ∈ (GLFW.PRESS, GLFW.REPEAT)
released(m::Mouse)    = m.action == GLFW.RELEASE
released(k::Keyboard) = k.action == GLFW.RELEASE

# Mouse Picking Stuff
@component_with_kw struct Selectable <: ComponentData
	selected::Bool = false
	color_modifier::Float32 = 1.3f0
end

struct IDColorGenerator <: System end

Overseer.requested_components(::IDColorGenerator) = (PolygonGeometry, Selectable, IDColor)

function Overseer.update(::IDColorGenerator, m::AbstractLedger)
	idc, selectable =  m[IDColor], m[Selectable]
	i = length(idc)
    for e in @entities_in(selectable && !idc)
        idc[e] = IDColor(RGBf0(((i & 0x000000FF) >>  0)/ 255,((i & 0x0000FF00) >>  8)/255, ((i & 0x00FF0000) >> 16)/255))
        i+=1
    end
end

struct MousePicker <: System end

Overseer.requested_components(::MousePicker) = (Selectable, Camera3D, Spatial, UniformColor, Canvas, UpdatedComponents)

function Overseer.update(::MousePicker, m::AbstractLedger)
	col                = m[IDColor]
	ucolor             = m[UniformColor]
	sel                = m[Selectable]
	canvas             = singleton(m, Canvas)
	updated_components = singleton(m, UpdatedComponents)
	mouse = singleton(m, Mouse)
	keyboard = singleton(m, Keyboard)
	wh                 = size(canvas)

	iofbo = singleton(m, IOTarget).target

	@inbounds if pressed(keyboard) && keyboard.button ∈ CTRL_KEYS && mouse.button == GLFW.MOUSE_BUTTON_1

        glFlush()
    	bind(iofbo)
    	glReadBuffer(GL_COLOR_ATTACHMENT1)

        glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
        dat = Ref{RGBf0}()
    	# screenspace = (2 * cursor_position[1] / wh[1] - 1,  1-2*cursor_position[2]/wh[2])
        glReadPixels(mouse.x, wh[2]-mouse.y, 1, 1, GL_RGB, GL_FLOAT, dat)
        unbind(iofbo)
        selected_color = dat[]

		for e in @entities_in(col && ucolor)
    		e_color = col[e]
    		s = sel[e]
    		mod = s.color_modifier
    		o_c = ucolor[e].color
    		if isapprox(e_color.color, selected_color) && pressed(mouse)
				was_selected = s.selected
				sel[e] = Selectable(true, s.color_modifier)
				if !was_selected 
					ucolor[e] = UniformColor(RGB(o_c.r * mod, o_c.g * mod, o_c.b * mod))
					push!(updated_components.components, UniformColor)
				end
			elseif !isapprox(e_color.color, selected_color) && released(mouse)
				was_not_selected = s.selected
				sel[e] = Selectable(false, s.color_modifier)
				if was_not_selected 
					ucolor[e] = UniformColor(RGB(o_c.r / mod, o_c.g / mod, o_c.b / mod))
					push!(updated_components.components, UniformColor)
				end
			end
		end
	end
end

