# # This function defines the case study and reads its data once
# # Then, it formulates coalitions of lines and FL to analyse
# # Finally, it iteratively calls the main ACSCOPF tool for each coalition
# # (Andrey Churkin, Sept 2023)

using JuMP,OdsIO,MathOptInterface,Dates,LinearAlgebra
using Ipopt, JSON

# # https://discourse.julialang.org/t/how-to-clear-variables-and-or-whole-work-space/10149/26
# function unbindvariables()
#     for name in names(Main)
#         if !isconst(Main, name)
#             Main.eval(:($name = nothing))
#         end
#     end
# end

# # Define case study:
# filename = "input_data/C5.ods"
# filename = "input_data/UK.ods"
# filename = "input_data/UK_2.ods"
# filename = "input_data/UK_2_test.ods"
filename = "input_data/UK_2_test_RES.ods"


# # OPF modelling options:
OPF_opt = 0 # single-period SCACOPF
# OPF_opt = 1 # multi-period OPF

# # Objective function options:
# Obj_f_opt = 0 # original total cost minimisation objective: gen cost + load curtailment + flex cost
# Obj_f_opt = 1 # minimise load curtailment only
Obj_f_opt = 2 #  total expected cost (stochastic optimisation): 0.95 notmal state + 0.05*(1/nSc) contingency states

# # Investment modelling options:
# Inv_opt = 0 # original AC SCOPF model - new lines and flexibility providers are added as input parameters
Inv_opt = 1 # investment options are explicitly formulated as variables in the optimisation model


# # Data reading functions from main.jl
show(pwd());
cd(dirname(@__FILE__))
println("")
show(pwd());
filename_scenario= "input_data/scenario_gen.ods"
include("data_preparation/data_types.jl")
include("data_preparation/data_types_contingencies.jl")
include("data_preparation/data_reader.jl")
include("data_preparation/interface_excel.jl")
global array_lines_0 = deepcopy(array_lines) # initial capacity of lines read from ODS
include("functions/network_topology_functions.jl")
include("functions/AC_SCOPF_functions.jl")
include("data_preparation/contin_scen_arrays.jl")
global data_for_each_contingency_0 = deepcopy(data_for_each_contingency) # initial capacity of lines for contingencies
include("data_preparation/node_data_func.jl")
global prof_ploads_0 = deepcopy(prof_ploads) # initial data from ODS
global prof_qloads_0 = deepcopy(prof_qloads) # initial data from ODS
global pg_max_0 = deepcopy(pg_max) # initial data from ODS
global qg_max_0 = deepcopy(qg_max) # initial data from ODS
global pg_min_0 = deepcopy(pg_min) # initial data from ODS
global qg_min_0 = deepcopy(qg_min) # initial data from ODS


lines_inv_cost = 5 # reinforcement costs $/MWh
lines_inv_costs = ones(nLines)*lines_inv_cost


# # Cooperative Game Theory functions:
include("Shapley_matrix_Julia1.jl")
include("Shapley_value_Julia1.jl")

# nPl = 8 # number of players
# nPl = nBus + nLines # consider all lines and FL for the UK case
# nPl = 10 # UK case with 10 players
nPl = 7 # UK case with 7 players

# # use full or truncated colalitional structure for analysis:
use_trunc_coal_struct = 0 # full
# use_trunc_coal_struct = 1 # truncated

# pl_titles = ["L1-2" "L1-3" "L1-4" "L2-5" "L3-4" "L4-5" "F1" "F2"]
# pl_titles = [ "L7-8" "L11-13" "L17-16" "F20" "F24" "F25" "F26" "F27" "F28"	"F29"] # UK case with 10 players
pl_titles = [ "L7-8" "L11-13" "L17-16" "F25" "F26" "F27" "F28"] # UK case with 7 players

# global pl_titles = Vector{String}()
# for l = 1:nLines
#     global pl_titles = vcat(pl_titles,["L"*string(array_lines[l].line_from)*"-"*string(array_lines[l].line_to)])
# end
# for f = 1:nBus
#     global pl_titles = vcat(pl_titles,["F"*string(f)])
# end

if use_trunc_coal_struct == 0
    global u = Shapley_matrix(nPl) # get the scenarios (possible coalitions)
else # create a truncated coalitional structure: (0), (1), (N-1), (N)
    u_0 = zeros(nPl)
    u_1 = ones(nPl)
    global u = vcat(u_0',u_1')
    for pl = 1:nPl
        u_0_plus1 = deepcopy(u_0)
        u_0_plus1[pl] = 1
        global u = vcat(u,u_0_plus1')
    end
    for pl = 1:nPl
        u_1_minus1 = deepcopy(u_1)
        u_1_minus1[pl] = 0
        global u = vcat(u,u_1_minus1')
    end
end

if use_trunc_coal_struct == 1
    u_truncated = zeros(nPl)' # create a truncated coalitional structure
    for i = 1:size(u)[1]
        if sum(u[i,:]) == 1 # consider coalitions of 1
            global u_truncated = vcat(u_truncated,u[i,:]')
        elseif sum(u[i,:]) == nPl # consider the grand coalition
            global u_truncated = vcat(u_truncated,u[i,:]')
        elseif sum(u[i,:]) == nPl-1 # consider coalitions N-1
            global u_truncated = vcat(u_truncated,u[i,:]')
        end
    end
    u = u_truncated # analyse only the truncated coalitional structure
end

# # characteristic functions:
    Vfunction_max_plc = zeros(size(u)[1]) # P load curtailment
    Vfunction_max_qlc = zeros(size(u)[1]) # Q load curtailment
    Vfunction_total_cost = zeros(size(u)[1]) # costs

# if_pl_lines = [1 1 1 1 1 1 0 0] # define players: 1 = line, 0 = flexibility
# if_pl_lines = [ones(nLines)' zeros(nBus)'] # consider all lines and FL for the UK case
# if_pl_lines = [1 1 1 0 0 0 0 0 0 0] # UK case with 10 players
if_pl_lines = [1 1 1 0 0 0 0] # UK case with 7 players

# pl_lines_numbers = [1 2 3 4 5 6] # number of each line player
# pl_lines_numbers = collect(1:nLines) # number of each line player
# pl_lines_numbers = [9 16 27] # UK case with 10 players
pl_lines_numbers = [9 16 27] # UK case with 7 players

# pl_flex_numbers = [1 2] # bus of flexibility players
# pl_flex_numbers = collect(1:nBus) # bus of flexibility players
# pl_flex_numbers = [20 24 25 26 27 28 29] # UK case with 10 players
pl_flex_numbers = [25 26 27 28] # UK case with 7 players




# pl_capacity = [1000 1000 1000 1000 1000 1000 1000 1000] # additional capacity limit of lines and flex. units (in MW)
# pl_capacity = [0 0 0 0 0 0 0 0]
# pl_capacity = [500 500 500 500 500 500 500 500]
# pl_capacity = [200 200 200 200 200 200 200 200]
# pl_capacity = [200 200 200 200 200 200 0 0]
# pl_capacity = [100 100 100 100 100 100 100 100]

pl_capacity = ones(nLines + nBus)*1000 # for the UK case
# pl_capacity = ones(nLines + nBus)*0 # tests for the UK case



global coalition_term_status = [] # write down Ipopt termination statuses for every coalition
global coalition_elapsed_time = [] # write down ACSCOPF elapsed times for every coalition

for coalition = 1:size(u)[1]
    println()
    println("coalition #",coalition,": ",u[coalition,:]')
    println()
    local json_file_path = "data_preparation\\import_WP3.json" # file to update for each coalition

    # # Delete old JSON file before saving new data
    if isfile(json_file_path)
        rm(json_file_path)
        println("import_WP3.json deleted successfully")
    else
        println("import_WP3.json does not exist!")
    end

    local new_gen_cost=0.1
    local OPF_opt=0
    local load_multiplier=1.0
    local gen_multiplier=1.0
    # local load_multiplier=1.93 # for the UK case
    # local gen_multiplier=1.546 # for the UK case
    local investment=zeros(nLines,1)
    local Pfl_inc=zeros(nBus,1)
    local Pfl_dec=zeros(nBus,1)
    local Qfl_inc=zeros(nBus,1)
    local Qfl_dec=zeros(nBus,1)

    count_lines = 0
    count_flex = 0
    for i = 1:nPl # modify planning options player by player
        if if_pl_lines[i] == 1 # this player is a line
            count_lines += 1
            investment[pl_lines_numbers[count_lines]] = pl_capacity[i]*u[coalition,i]
        else # this player is flexibility
            count_flex += 1
            Pfl_inc[pl_flex_numbers[count_flex]] = pl_capacity[i]*u[coalition,i]
            Pfl_dec[pl_flex_numbers[count_flex]] = pl_capacity[i]*u[coalition,i]
            # # Q flex is disabled in this simulation:
            # Qfl_inc[pl_flex_numbers[count_flex]] = pl_capacity[i]*u[coalition,i]
            # Qfl_dec[pl_flex_numbers[count_flex]] = pl_capacity[i]*u[coalition,i]
        end
    end

    local s_input=Dict("ci" => investment,
        "Pflex_inc" => Pfl_inc,
        "Pflex_dec" => Pfl_dec,
        "Qflex_inc" => Qfl_inc,
        "Qflex_dec" => Qfl_dec,
        # "negGen"    => negative_gen, # removed for the PSCC simulations
        "gencost"   => new_gen_cost,
        "OPF_opt"   => OPF_opt,
        "load_multiplier"=> load_multiplier,
        "gen_multiplier" => gen_multiplier,
        )
    local stringdata = JSON.json(s_input)
    # Please note that parallel lines are merged initially,
    open("data_preparation\\import_WP3.json", "a") do f
    write(f, stringdata)
    end

    # # solve ACSCOPF using the main ACSCOPF function
    
    include("main_iterative.jl")   
    Vfunction_max_plc[coalition] = maximum([maximum(active_load_curt[1]), maximum(Iterators.flatten(active_load_curt_c))])
    Vfunction_max_qlc[coalition] = maximum([maximum(reactive_load_curt[1]), maximum(Iterators.flatten(reactive_load_curt_c))])
    Vfunction_total_cost[coalition] = JuMP.objective_value(model_name)

    global coalition_term_status = vcat(coalition_term_status, JuMP.termination_status(model_name))
    global coalition_elapsed_time = vcat(coalition_elapsed_time, elapsed_time)

    # # Delete the model to free up memory:
    global model_name = nothing
    global AC_SCOPF = nothing
    # gc() # garbage collector - not woking in Julia anymore
    global output = nothing # - does not help much
    # unbindvariables() # - too radical

    # exit()

end

# # Computing marginal contributions for the players:
MC_individual_plot = zeros(nPl)
MC_grand_coalition_plot = zeros(nPl)
if Obj_f_opt == 1 # load curtailment optimisation
    if use_trunc_coal_struct == 1 # consider only truncated coalitional structure
        MC_truncated = zeros(2,nPl) # only individual (row 1) and grand coalition (row 2)
        for pl = 1:nPl
            # # Individual contributions: 
            u_without_pl = zeros(nPl)
            u_with_pl = copy(u_without_pl)
            u_with_pl[pl] = 1
            row_index_without = findall(all(u .== u_without_pl', dims=2))[1][1]
            row_index_with = findall(all(u .== u_with_pl', dims=2))[1][1]
            MC_truncated[1,pl] = Vfunction_max_plc[row_index_with] - Vfunction_max_plc[row_index_without]
            # # Contributions to the grand coalition: 
            u_with_pl = ones(nPl)
            u_without_pl = copy(u_with_pl)
            u_without_pl[pl] = 0
            row_index_without = findall(all(u .== u_without_pl', dims=2))[1][1]
            row_index_with = findall(all(u .== u_with_pl', dims=2))[1][1]
            MC_truncated[2,pl] = Vfunction_max_plc[row_index_with] - Vfunction_max_plc[row_index_without]
        end
    else
        MC_full = zeros(Int((2^nPl)/2),nPl) # coalitions of 1, 2, ..., nPl
        for pl = 1:nPl # estimate constributions for each player
            coalition_found = 0 # found a coalition with this player
            for coalition = 1:size(u)[1] # check every coalition with the player
                if u[coalition,pl] == 1
                    coalition_found += 1
                    u_with_pl = deepcopy(u[coalition,:])
                    u_without_pl = deepcopy(u_with_pl)
                    u_without_pl[pl] = 0
                    row_index_with = findall(all(u .== u_with_pl', dims=2))[1][1]
                    row_index_without = findall(all(u .== u_without_pl', dims=2))[1][1]
                    MC_full[coalition_found,pl] = Vfunction_max_plc[row_index_with] - Vfunction_max_plc[row_index_without]
                    if sum(u[coalition,:]) == 1 # individual contribution
                        MC_individual_plot[pl] = Vfunction_max_plc[row_index_with] - Vfunction_max_plc[row_index_without]
                    elseif sum(u[coalition,:]) == nPl # grand coalition
                        MC_grand_coalition_plot[pl] = Vfunction_max_plc[row_index_with] - Vfunction_max_plc[row_index_without]
                    end
                end

            end

        end

    end
    if use_trunc_coal_struct == 0
        empty_coalition = findall(all(u .== zeros(nPl)', dims=2))[1][1]
        Vfunction_avoided_LC = Vfunction_max_plc[empty_coalition] .- Vfunction_max_plc # avoided load curtailment
        Shapley_max_plc = Shapley_value(nPl,Vfunction_avoided_LC[1:end-1,:]) # compute the Shapley value
    end
elseif Obj_f_opt == 2 # total expected cost - stochastic optimisation
    if use_trunc_coal_struct == 1 # consider only truncated coalitional structure
        MC_truncated = zeros(2,nPl) # only individual (row 1) and grand coalition (row 2)
        for pl = 1:nPl
            # # Individual contributions: 
            u_without_pl = zeros(nPl)
            u_with_pl = copy(u_without_pl)
            u_with_pl[pl] = 1
            row_index_without = findall(all(u .== u_without_pl', dims=2))[1][1]
            row_index_with = findall(all(u .== u_with_pl', dims=2))[1][1]
            MC_truncated[1,pl] = Vfunction_total_cost[row_index_with] - Vfunction_total_cost[row_index_without]
            # # Contributions to the grand coalition: 
            u_with_pl = ones(nPl)
            u_without_pl = copy(u_with_pl)
            u_without_pl[pl] = 0
            row_index_without = findall(all(u .== u_without_pl', dims=2))[1][1]
            row_index_with = findall(all(u .== u_with_pl', dims=2))[1][1]
            MC_truncated[2,pl] = Vfunction_total_cost[row_index_with] - Vfunction_total_cost[row_index_without]
        end
    else
        MC_full = zeros(Int((2^nPl)/2),nPl) # coalitions of 1, 2, ..., nPl
        for pl = 1:nPl # estimate constributions for each player
            coalition_found = 0 # found a coalition with this player
            for coalition = 1:size(u)[1] # check every coalition with the player
                if u[coalition,pl] == 1
                    coalition_found += 1
                    u_with_pl = deepcopy(u[coalition,:])
                    u_without_pl = deepcopy(u_with_pl)
                    u_without_pl[pl] = 0
                    row_index_with = findall(all(u .== u_with_pl', dims=2))[1][1]
                    row_index_without = findall(all(u .== u_without_pl', dims=2))[1][1]
                    MC_full[coalition_found,pl] = Vfunction_total_cost[row_index_with] - Vfunction_total_cost[row_index_without]
                    if sum(u[coalition,:]) == 1 # individual contribution
                        MC_individual_plot[pl] = Vfunction_total_cost[row_index_with] - Vfunction_total_cost[row_index_without]
                    elseif sum(u[coalition,:]) == nPl # grand coalition
                        MC_grand_coalition_plot[pl] = Vfunction_total_cost[row_index_with] - Vfunction_total_cost[row_index_without]
                    end
                end

            end

        end

    end
    if use_trunc_coal_struct == 0
        empty_coalition = findall(all(u .== zeros(nPl)', dims=2))[1][1]
        Vfunction_avoided_cost = Vfunction_total_cost[empty_coalition] .- Vfunction_total_cost # avoided cost
        Shapley_max_plc = Shapley_value(nPl,Vfunction_avoided_cost[1:end-1,:]) # compute the Shapley value
    end
end


## Save coalitional analysis results to JLD
# using JLD
# save("coalitional_analysis_output_UK_RES_test2.jld"
#      , "Vfunction_max_plc",Vfunction_max_plc
#      , "Vfunction_max_qlc",Vfunction_max_qlc
#      , "Vfunction_total_cost",Vfunction_total_cost
#      , "coalition_term_status",coalition_term_status
#      , "coalition_elapsed_time",coalition_elapsed_time
# )


## Save coalitional analysis results to CSV
# using CSV, DataFrames
# CSV.write("coalitional_analysis_output_UK_7pl_test1_Vfunction_max_plc.csv",  DataFrame(Names=("Vfunction_max_plc"), Vector=Vfunction_max_plc))
# CSV.write("coalitional_analysis_output_UK_7pl_test1_Vfunction_max_qlc.csv",  DataFrame(Names=("Vfunction_max_qlc"), Vector=Vfunction_max_qlc))
# CSV.write("coalitional_analysis_output_UK_7pl_test1_coalition_term_status.csv",  DataFrame(Names=("coalition_term_status"), Vector=coalition_term_status))
# CSV.write("coalitional_analysis_output_UK_7pl_test1_coalition_elapsed_time.csv",  DataFrame(Names=("coalition_elapsed_time"), Vector=coalition_elapsed_time))
# # export_contributions = -MC_truncated*sbase
# # CSV.write("coalitional_screening_UK.csv",  DataFrame(export_contributions, :auto))


## Plotting figures for the coalitional analysis:
using Plots, Plots.PlotMeasures

if Obj_f_opt == 1 # load curtailment optimisation
    y = Vfunction_max_plc
elseif Obj_f_opt == 2 # total expected cost - stochastic optimisation
    y = Vfunction_total_cost
end

plt = scatter(ones(size(y)[1]),y,
markersize = 10,
color=palette(:tab10)[4],
label = "LC",
title="LC",titlefontsize=30,fontfamily="Courier",
size=(2000,2000),
# xlim=(0,60),ylim=(0,20000),
alpha = 0.3,
xtickfontsize=30,ytickfontsize=30,xguidefontsize=30,legendfontsize=30,
xlabel="x",
foreground_color_legend = nothing, legend = false,
framestyle=:box, margin=20mm, left_margin=50mm, minorgrid=:true)

display(plt)



## Violin diagrams:
using StatsPlots, DataFrames, CSV
# y = Vfunction_max_plc*sbase

# # Activate to remove negative impacts of lines (due to manual optimisation):
for i = 1:size(MC_full)[1]
    for j = 1:size(MC_full)[2]
        if MC_full[i,j] > 0
            global MC_full[i,j] = 0
        end
    end
end

if use_trunc_coal_struct == 0
    y = -MC_full*sbase
else
    y = -MC_truncated*sbase
end

viloin_color = :grey

# plot_scale = 1
# plot_scale = 1/10^4
plot_scale = 1/10^3
# plot_scale = 1/10^2

if Obj_f_opt == 2 # total expected cost - stochastic optimisation
    # viloin_color = :grey
    viloin_color = palette(:tab10)[1]
    # viloin_color = RGB(30/255,227/255,221/255)
    # viloin_color = RGB(30/255,135/255,227/255)

    y = y*plot_scale # for nice C5 case plots

end

# plt = violin(pl_titles, y,
plt = violin(collect(1:nPl)',y,
    #   alpha=0.25,
      # alpha=0.1,
    #   alpha=1,
      alpha=0.75,
      lw = 3,
      # linecolor =
      # color=palette(:tab10)[1],
      # color=palette(:tab10)[2],
      # color=palette(:tab10)[3],
    #   color = :grey,
    color = viloin_color,
    #   color=palette(:tab10)[6],
      # color = RGB(flex_color[1],flex_color[2],flex_color[3]),
      # linealpha = 0.7,
      # linealpha = 0.0,
      # linewidth=0.0,
      fontfamily = "Courier",
      size = (2000,2000),
    #   xlim=(0,nPl+1),
      # ylim = (0,maximum(time_records_loops)),
    #   ylim = (0,160),
      xlabel = "x", ylabel = "y",
      xtickfontsize = 30, ytickfontsize = 30, xguidefontsize = 30, yguidefontsize = 30, legendfontsize = 30,
      foreground_color_legend = nothing, legend = false,
      framestyle = :box, margin = 20mm, left_margin = 50mm, yminorgrid = :true,
      xticks = (1:nPl, string.(1:nPl)),
      # aspect_ratio=:equal
      # fill_z = 1 - (f)/F,
      # color = palette([RGB(0,0,0), RGB(1,1,1)], F)
)

for pl = 1:nPl
    if use_trunc_coal_struct == 0
        scatter!(plt,ones(size(MC_full)[1])*pl, -MC_full[:,pl]*sbase*plot_scale,
                    # markersize = 20,
                    markersize = 5,
                    # markershape = :cross,
                    # markershape = :hline,
                    markershape = :circle,
                    # markercolor = :grey
                    markercolor = RGB(0.1,0.1,0.1)
        )

        scatter!(plt,[pl], [-MC_individual_plot[pl]]*sbase*plot_scale,
        markersize = 20,
        # markersize = 5,
        markershape = :cross,
        # markershape = :hline,
        # markershape = :circle,
        # markercolor = :red,
        markerstrokewidth = 1.3,
        markercolor = RGB(227/255,30/255,36/255)
        )

        scatter!(plt,[pl], [-MC_grand_coalition_plot[pl]]*sbase*plot_scale,
        markersize = 20,
        # markersize = 5,
        markershape = :x,
        markerstrokewidth = 1.3,
        # markershape = :hline,
        # markershape = :circle,
        # markercolor = :red
        markercolor = RGB(227/255,30/255,36/255)
        )

        scatter!(plt,[pl], [Shapley_max_plc[pl]]*sbase*plot_scale,
        markersize = 20,
        # markersize = 5,
        # markershape = :xcross,
        # markershape = :hline,
        markershape = :diamond,
        # markercolor = :red,
        # markerstrokecolor = :red,
        # markerstrokewidth = 1.2,
        markercolor = RGB(227/255,30/255,36/255)
        )
    end
end

display(plt)

# # figure_name = "UK - violin plots - 7pl test1"
# figure_name = "UK - violin plots - RES test2"
# # figure_name = "UK - violin plots - 10sc LC test1"
# savefig(figure_name*".svg")
# savefig(figure_name*".png")
