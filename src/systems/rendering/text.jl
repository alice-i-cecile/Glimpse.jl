struct TextProgram <: ProgramKind end

struct TextUploader <: System end
requested_components(::TextUploader) = (Text, Vao{TextProgram}, RenderProgram{TextProgram}, FontStorage)

function ECS.prepare(::TextUploader, dio::Diorama)
	if isempty(dio[RenderProgram{TextProgram}])
		Entity(dio, RenderProgram{TextProgram}(Program(text_shaders())))
	end
	if isempty(dio[FontStorage])
		Entity(dio, FontStorage())
	end
end

function (::TextUploader)(m)
	text = m[Text]
	vao  = m[Vao{TextProgram}]
	prog = m[RenderProgram{TextProgram}][1]
	fontstorage = m[FontStorage][1]

	for (e, t) in ECS.EntityIterator(text)
		space_o_wh, uv_offset_width  = to_gl_text(t, fontstorage)
		vao[e] = Vao{TextProgram}(VertexArray([generate_buffers(prog.program,
		                                                        GEOMETRY_DIVISOR,
		                                                        uv=Vec2f0.([(0, 1),
		                                                                    (0, 0),
		                                                                    (1, 1),
		                                                                    (1,0)]));
                                               generate_buffers(prog.program,
                                                                GLint(1),
                                                                space_o_wh      = space_o_wh,
                                                                uv_offset_width = uv_offset_width)],
                                               collect(0:3), GL_TRIANGLE_STRIP, length(text[e].str)), true)
	end
end

to_gl_text(t::Text, storage::FontStorage) = to_gl_text(t.str, t.font_size, t.font, t.align, storage)

function to_gl_text(string::AbstractString, textsize::Int, font::Vector{Ptr{AP.FreeType.FT_FaceRec}}, align::Symbol, storage::FontStorage)
    atlas           = storage.atlas
    rscale          = Float32(textsize)
    chars           = Vector{Char}(string)
    scale           = Vec2f0.(AP.glyph_scale!.(Ref(atlas), chars, (font,), rscale))
    positions2d     = AP.calc_position(string, Point2f0(0), rscale, font, atlas)

    aoffset         = AbstractPlotting.align_offset(Point2f0(0), positions2d[end], atlas, rscale, font, align)
    uv_offset_width = AP.glyph_uv_width!.(Ref(atlas), chars, (font,))
    out_uv_offset_width= Vec4f0[]
    for uv in uv_offset_width
	    push!(out_uv_offset_width, Vec4f0(uv[1], uv[2], uv[3] - uv[1], uv[4] - uv[2]))
    end
    out_pos_scale = Vec4f0[]
    for (p, sc) in zip(positions2d .+ (aoffset,), scale)
	    push!(out_pos_scale, Vec4f0(p[1], p[2], sc[1], sc[2]))
    end
    return out_pos_scale, out_uv_offset_width
end


struct TextRenderer <: AbstractRenderSystem end
# 	data ::SystemData

requested_components(::TextRenderer) =
	(Spatial, UniformColor, Camera3D, Vao{TextProgram}, Text,
		RenderProgram{TextProgram}, RenderTarget{IOTarget}, FontStorage)

function (::TextRenderer)(m)
	spat      = m[Spatial]
	col       = m[UniformColor]
	prog      = m[RenderProgram{TextProgram}][1]
	cam       = m[Camera3D]
	vao       = m[Vao{TextProgram}]
	iofbo     = m[RenderTarget{IOTarget}][1]
	persp_mat = cam[1].projview
	text      = m[Text]
	wh = size(iofbo)

	glEnable(GL_DEPTH_TEST)
	glDepthFunc(GL_LEQUAL)

	glyph_fbo = m[FontStorage][1].storage_fbo
	bind(color_attachment(glyph_fbo, 1))
    bind(iofbo)
    draw(iofbo)

	bind(prog)
	set_uniform(prog, :canvas_dims, Vec2f0(wh))
    set_uniform(prog, :projview, persp_mat)
	set_uniform(prog, :glyph_texture, (0, color_attachment(glyph_fbo, 1)))
	for (e_vao, e_spat, e_text, e_col) in zip(vao, spat, text, col)
		set_uniform(prog, :start_pos, e_spat.position + e_text.offset)
		set_uniform(prog, :color, e_col.color)
		bind(e_vao)
		draw(e_vao)
	end
end

