using Colors

# this function is copy from [GraphLayout.jl](https://github.com/IainNZ/GraphLayout.jl) and make some modifications.
"""
Given a graph and two vectors of X and Y coordinates, returns
a Compose tree of the graph layout

**Arguments**

`G`
Graph to draw

`layout`
Optional. Layout algorithm. Currently can be one of [`random_layout`,
`circular_layout`, `spring_layout`, `shell_layout`, `stressmajorize_layout`,
`spectral_layout`].
Default: `spring_layout`

`locs_x, locs_y`
Locations of the nodes. Can be any units you want,
but will be normalized and centered anyway

`NODESIZE`
Optional. Max size for the nodes. Default: `3.0/sqrt(N)`

`nodesize`
Optional. Relative size for the nodes, can be a Vector. Default: `1.0`

`nodelabel`
Optional. Labels for the vertices, a Vector or nothing. Default: `nothing`

`nodelabelc`
Optional. Color for the node labels, can be a Vector. Default: `colorant"black"`

`nodelabeldist`
Optional. Distances for the node labels from center of nodes. Default: `0.0`

`nodelabelangleoffset`
Optional. Angle offset for the node labels. Default: `π/4.0`

`NODELABELSIZE`
Optional. Largest fontsize for the vertice labels. Default: `4.0`

`nodelabelsize`
Optional. Relative fontsize for the vertice labels, can be a Vector. Default: `1.0`

`nodefillc`
Optional. Color to fill the nodes with, can be a Vector. Default: `colorant"turquoise"`

`nodestrokec`
Optional. Color for the nodes stroke, can be a Vector. Default: `nothing`

`nodestrokelw`
Optional. Line width for the nodes stroke, can be a Vector. Default: `0.0`

`edgelabel`
Optional. Labels for the edges, a Vector or nothing. Default: `[]`

`edgelabelc`
Optional. Color for the edge labels, can be a Vector. Default: `colorant"black"`

`edgelabeldistx, edgelabeldisty`
Optional. Distance for the edge label from center of edge. Default: `0.0`

`EDGELABELSIZE`
Optional. Largest fontsize for the edge labels. Default: `4.0`

`edgelabelsize`
Optional. Relative fontsize for the edge labels, can be a Vector. Default: `1.0`

`EDGELINEWIDTH`
Optional. Max line width for the edges. Default: `0.25/sqrt(N)`

`edgelinewidth`
Optional. Relative line width for the edges, can be a Vector. Default: `1.0`

`edgestrokec`
Optional. Color for the edge strokes, can be a Vector. Default: `colorant"lightgray"`

`arrowlengthfrac`
Optional. Fraction of line length to use for arrows.
Equal to 0 for undirected graphs. Default: `0.1` for the directed graphs

`arrowangleoffset`
Optional. Angular width in radians for the arrows. Default: `π/9 (20 degrees)`

"""
function gplot(g::AbstractGraph{T},
    locs_x_in::Vector{R}, locs_y_in::Vector{R};
    nodelabel = nothing,
    nodelabelc = colorant"black",
    nodelabelsize = 1.0,
    NODELABELSIZE = 4.0,
    nodelabeldist = 0.0,
    nodelabelangleoffset = π / 4.0,
    edgelabel = [],
    edgelabelc = colorant"black",
    edgelabelsize = 1.0,
    EDGELABELSIZE = 4.0,
    edgestrokec = colorant"lightgray",
    edgelinewidth = 1.0,
    EDGELINEWIDTH = 3.0 / sqrt(nv(g)),
    edgelabeldistx = 0.0,
    edgelabeldisty = 0.0,
    nodesize = 1.0,
    NODESIZE = 0.25 / sqrt(nv(g)),
    nodefillc = colorant"turquoise",
    nodestrokec = nothing,
    nodestrokelw = 0.0,
    arrowlengthfrac = is_directed(g) ? 0.1 : 0.0,
    arrowangleoffset = π / 9.0,
    linetype = "straight",
    outangle = pi/5) where {T <:Integer, R <: Real}

    length(locs_x_in) != length(locs_y_in) && error("Vectors must be same length")
    N = nv(g)
    NE = ne(g)
    if nodelabel != nothing && length(nodelabel) != N
        error("Must have one label per node (or none)")
    end
    if !isempty(edgelabel) && length(edgelabel) != NE
        error("Must have one label per edge (or none)")
    end

    locs_x = Float64.(locs_x_in)
    locs_y = Float64.(locs_y_in)

    # Scale to unit square
    min_x, max_x = extrema(locs_x)
    min_y, max_y = extrema(locs_y)
    function scaler(z, a, b)
        2.0 * ((z - a) / (b - a)) - 1.0
    end
    map!(z -> scaler(z, min_x, max_x), locs_x, locs_x)
    map!(z -> scaler(z, min_y, max_y), locs_y, locs_y)

    # Determine sizes
    #NODESIZE    = 0.25/sqrt(N)
    #LINEWIDTH   = 3.0/sqrt(N)

    max_nodesize = NODESIZE / maximum(nodesize)
    nodesize *= max_nodesize
    max_edgelinewidth = EDGELINEWIDTH / maximum(edgelinewidth)
    edgelinewidth *= max_edgelinewidth
    max_edgelabelsize = EDGELABELSIZE / maximum(edgelabelsize)
    edgelabelsize *= max_edgelabelsize
    max_nodelabelsize = NODELABELSIZE / maximum(nodelabelsize)
    nodelabelsize *= max_nodelabelsize
    max_nodestrokelw = maximum(nodestrokelw)
    if max_nodestrokelw > 0.0
        max_nodestrokelw = EDGELINEWIDTH / max_nodestrokelw
        nodestrokelw *= max_nodestrokelw
    end

    # Create nodes
    nodecircle = fill(0.4Compose.w, length(locs_x))
    if isa(nodesize, Real)
        	    for i = 1:length(locs_x)
            	    	nodecircle[i] *= nodesize
        	    end
    	else
        		for i = 1:length(locs_x)
            	    	nodecircle[i] *= nodesize[i]
        	    end
    	end
    nodes = circle(locs_x, locs_y, nodecircle)

    # Create node labels if provided
    texts = nothing
    if nodelabel != nothing
        text_locs_x = deepcopy(locs_x)
        text_locs_y = deepcopy(locs_y)
        texts = text(text_locs_x .+ nodesize .* (nodelabeldist * cos(nodelabelangleoffset)),
                     text_locs_y .- nodesize .* (nodelabeldist * sin(nodelabelangleoffset)),
                     map(string, nodelabel), [hcenter], [vcenter])
    end
    # Create edge labels if provided
    edgetexts = nothing
    if !isempty(edgelabel)
        edge_locs_x = zeros(R, NE)
        edge_locs_y = zeros(R, NE)
        for (e_idx, e) in enumerate(edges(g))
            i = src(e)
            j = dst(e)
            mid_x = (locs_x[i]+locs_x[j]) / 2.0
            mid_y = (locs_y[i]+locs_y[j]) / 2.0
            edge_locs_x[e_idx] = (is_directed(g) ? (mid_x+locs_x[j]) / 2.0 : mid_x) + edgelabeldistx * NODESIZE
            edge_locs_y[e_idx] = (is_directed(g) ? (mid_y+locs_y[j]) / 2.0 : mid_y) + edgelabeldisty * NODESIZE

        end
        edgetexts = text(edge_locs_x, edge_locs_y, map(string, edgelabel), [hcenter], [vcenter])
    end

    # Create lines and arrow heads
    lines, arrows = nothing, nothing
    if linetype == "curve"
        if arrowlengthfrac > 0.0            
            curves_cord, arrows_cord = GraphPlot.graphcurve(g, locs_x, locs_y, nodesize, arrowlengthfrac, arrowangleoffset, outangle)
            lines = [ curve(curves_cord[i,1], curves_cord[i,2], curves_cord[i,3], curves_cord[i,4]) for i in 1:size(curves_cord)[1]]
            arrows = [line(arrows_cord[i]) for i in 1:size(arrows_cord)[1] ]
        else
            curves_cord = GraphPlot.graphcurve(g, locs_x, locs_y, nodesize, outangle)
            lines = [ curve(curves_cord[i,1], curves_cord[i,2], curves_cord[i,3], curves_cord[i,4]) for i in 1:size(curves_cord)[1]]
        end
    else
        if arrowlengthfrac > 0.0
            lines_cord, arrows_cord = GraphPlot.graphline(g, locs_x, locs_y, nodesize, arrowlengthfrac, arrowangleoffset)
            lines = [ line(lines_cord[i]) for i in 1:size(lines_cord)[1]]
            arrows = [line(arrows_cord[i]) for i in 1:size(arrows_cord)[1]]
      
        else
            lines_cord = GraphPlot.graphline(g, locs_x, locs_y, nodesize)
            lines = [ line(lines_cord[i]) for i in 1:size(lines_cord)[1]]      
        end
    end  
  
    if !(typeof(edgestrokec) <: Array)
      _edgestrokec = Array{typeof(edgestrokec),1}(undef,size(lines)[1])    
      _edgestrokec .= edgestrokec      
    else
      _edgestrokec = edgestrokec  
    end 
  
    if !(typeof(edgelinewidth) <: Array)  
      _edgelinewidth = Array{typeof(edgelinewidth),1}(undef,size(lines)[1])      
      _edgelinewidth .= edgelinewidth
    else
        _edgelinewidth = edgelinewidth
    end
    compose_lst = []
    push!(compose_lst,compose(context(), texts, fill(nodelabelc), stroke(nothing), fontsize(nodelabelsize)))
    push!(compose_lst,compose(context(), nodes, fill(nodefillc), stroke(nodestrokec), linewidth(nodestrokelw)))
    push!(compose_lst,compose(context(), edgetexts, fill(edgelabelc), stroke(nothing), fontsize(edgelabelsize)))
    if arrows != nothing
        for i in 1:size(arrows)[1] 
            push!(compose_lst,compose(context(), arrows[i],stroke(_edgestrokec[i]), linewidth(_edgelinewidth[i])))
        end
    end
    if lines != nothing
        for i in 1:size(lines)[1]
            push!(compose_lst,compose(context(), lines[i] ,stroke(_edgestrokec[i]) ,linewidth(_edgelinewidth[i])))
        end
    end
    compose(context(units=UnitBox(-1.2, -1.2, +2.4, +2.4)),compose_lst...)
end

function gplot(g; layout::Function=spring_layout, keyargs...)
    gplot(g, layout(g)...; keyargs...)
end

# take from [Gadfly.jl](https://github.com/dcjones/Gadfly.jl)
function open_file(filename)
    if Sys.KERNEL == :Darwin
        run(`open $(filename)`)
    elseif Sys.KERNEL == :Linux || Sys.KERNEL == :FreeBSD
        run(`xdg-open $(filename)`)
    elseif Sys.KERNEL == :Windows
        run(`$(ENV["COMSPEC"]) /c start $(filename)`)
    else
        @warn("Showing plots is not supported on OS $(string(Sys.KERNEL))")
    end
end

# taken from [Gadfly.jl](https://github.com/dcjones/Gadfly.jl)
function gplothtml(g; layout::Function=spring_layout, keyargs...)
    filename = string(tempname(), ".html")
    output = open(filename, "w")

    plot_output = IOBuffer()
    draw(SVGJS(plot_output, Compose.default_graphic_width,
               Compose.default_graphic_width, false), gplot(g, layout(g)...; keyargs...))
    plotsvg = String(take!(plot_output))

    write(output,
        """
        <!DOCTYPE html>
        <html>
          <head>
            <title>GraphPlot Plot</title>
            <meta charset="utf-8">
          </head>
            <body>
            <script charset="utf-8">
                $(read(Compose.snapsvgjs, String))
            </script>
            <script charset="utf-8">
                $(read(gadflyjs, String))
            </script>
            $(plotsvg)
          </body>
        </html>
        """)
    close(output)
    open_file(filename)
end
