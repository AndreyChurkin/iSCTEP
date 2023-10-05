elapsed_time = @elapsed begin

# using JuMP,OdsIO,MathOptInterface,Dates,LinearAlgebra
# using Ipopt, JSON
# # using BenchmarkTools
# # using CPLEX
# # using SCIP       # It is not useful for our purpose. Mianly deals with the feasibility problem.
# # using AmplNLWriter
# # using Cbc

#-------------------Accessing current folder directory--------------------------
# show(pwd());
# cd(dirname(@__FILE__))
# println("")
# show(pwd());

# files = cd(readdir, string(pwd(),"\\Network_Data"))
#--------------------Read Data from the Excel file------------------------------
# @time begin

# # filename = "input_data/case_template_port_modified_R1.ods"
# # filename = "input_data/case60_bus_new_wind.ods"
# # filename = "input_data/C60.ods"
# filename = "input_data/C5.ods"
# # filename = "input_data/HR.ods"
# # filename = "input_data/PT.ods"
# # filename = "input_data/UK.ods"


# # filename = "input_data/case5_bus_new.ods"
# filename_scenario= "input_data/scenario_gen.ods"
# # filename_scenario= "scenario_gen.ods"
# # filename = "case_34_baran_modf.ods"

# include("data_preparation/data_types.jl")      # Reading the structure of network related fields

# include("data_preparation/data_types_contingencies.jl")

# include("data_preparation/data_reader.jl")     # Function setting the data corresponding to each network quantity

# include("data_preparation/interface_excel.jl") # Program saving all the inforamtion related to each entity of a power system


#-----------functions---------------------
# include("functions/network_topology_functions.jl") # <--- called only once (outside the loop) in coalitional_analysis.jl

# include("functions/AC_SCOPF_functions.jl")


#----------------------- Formatting of Network Data ----------------------------
# include("data_preparation/contin_scen_arrays.jl") # <--- called only once (outside the loop) in coalitional_analysis.jl

# include("data_preparation/node_data_func.jl") # <--- called only once (outside the loop) in coalitional_analysis.jl

# include("data_preparation\\json_generator.jl")

include("data_preparation/json_interface_import.jl")
# # Calling these functions again to update data:
(nw_buses,
nw_lines,
# nw_loads,
nw_gens,
nw_trans,
nw_sbase,
nw_shunts,
# nw_pPrf_header_load,
# nw_qPrf_header_load,
# nw_pPrf_data_load,
# nw_qPrf_data_load,
# prof_ploads,
# prof_qloads,
nw_storage,
sbase,
vbase,
Ibase,
load_inc_prct,
load_dec_prct,
pf,
v_relax_factor_min,
v_relax_factor_max,
bus_data_lsheet)=arrays_2(Load_MAG)

# global prof_ploads=load_multiplier*prof_ploads_0 # moved here again from json_interface_import.jl
# global prof_qloads=load_multiplier*prof_qloads_0

global p_lines_ckeck = 0
for line = 1:size(idx_plines)[1]
      global p_lines_ckeck += size(idx_plines[line])[1]
end

if p_lines_ckeck > nLines
      global have_parallel_lines = true
else
      global have_parallel_lines = false
end

# # Update capacity data for each contingency:

# if have_parallel_lines == false
#       for cont = 1:size(data_for_each_contingency)[1] # for each contingency
#             # println("cont = ",cont)
#             for cont_line_data = 1:size(data_for_each_contingency[cont])[1] # for each line in the contingency state
#                   upd_line_from = data_for_each_contingency[cont][cont_line_data].line_from
#                   upd_line_to = data_for_each_contingency[cont][cont_line_data].line_to
#                   for find_in_new_data = 1:size(array_lines)[1]
#                         if array_lines[find_in_new_data].line_from == upd_line_from
#                               if array_lines[find_in_new_data].line_to == upd_line_to
#                                     data_for_each_contingency[cont][cont_line_data].line_Smax_A = array_lines[find_in_new_data].line_Smax_A
#                               end
#                         end
#                   end
#             end
#       end
# else
#       data_for_each_contingency = deepcopy(data_for_each_contingency_0) # set capacities back to initial values
#       for cont = 1:size(data_for_each_contingency)[1] # for each contingency
#             for cont_line_data = 1:size(data_for_each_contingency[cont])[1] # for each line in the contingency state
#                   upd_line_from = data_for_each_contingency[cont][cont_line_data].line_from
#                   upd_line_to = data_for_each_contingency[cont][cont_line_data].line_to
#                   for find_in_new_data = 1:size(array_lines_reinf)[1]
#                         if array_lines_reinf[find_in_new_data].line_from == upd_line_from
#                               if array_lines_reinf[find_in_new_data].line_to == upd_line_to
#                                     data_for_each_contingency[cont][cont_line_data].line_Smax_A = data_for_each_contingency_0[cont][cont_line_data].line_Smax_A + array_lines_reinf[find_in_new_data].line_Smax_A
#                               end
#                         end
#                   end
#             end
#       end
# end

data_for_each_contingency = deepcopy(data_for_each_contingency_0) # set capacities back to initial values
for cont = 1:size(data_for_each_contingency)[1] # for each contingency
      for cont_line_data = 1:size(data_for_each_contingency[cont])[1] # for each line in the contingency state
            upd_line_from = data_for_each_contingency[cont][cont_line_data].line_from
            upd_line_to = data_for_each_contingency[cont][cont_line_data].line_to
            for find_in_new_data = 1:size(array_lines_reinf)[1]
                  if array_lines_reinf[find_in_new_data].line_from == upd_line_from
                        if array_lines_reinf[find_in_new_data].line_to == upd_line_to
                              data_for_each_contingency[cont][cont_line_data].line_Smax_A = data_for_each_contingency_0[cont][cont_line_data].line_Smax_A + array_lines_reinf[find_in_new_data].line_Smax_A
                        end
                  end
            end
      end
end


(idx_from_line_c,idx_to_line_c,yij_line_c,yij_line_sh_c,line_smax_c)=f_lines_data_contin(data_for_each_contingency) 


show("Initial functions are compiled. ")


    # AC_SCOPF = direct_model(Ipopt.Optimizer, add_bridges=false)
    AC_SCOPF = Model(Ipopt.Optimizer)
    # AC_SCOPF = Model()
    model_name=AC_SCOPF
    JuMP.bridge_constraints(model_name)=false


    model_name=AC_SCOPF


## Activate to select a specific hour (not hour #1) for SCOPF:
# if OPF_opt==0
#       prof_ploads = prof_ploads[:,19] 
#       prof_qloads = prof_qloads[:,19] 
# end


global (model_name,output)=SP_SCOPF_or_MP_OPF(OPF_opt)

if OPF_opt==0  
      # include("data_preparation/dualizing_SCOPF.jl") # <--- skipped to save time
      include("data_preparation/json_interface_export_SCOPF.jl") 
elseif OPF_opt==1
      # include("data_preparation/dualizing_MPOPF.jl") # <--- skipped to save time
      include("data_preparation/json_interface_export_MPOPF.jl")
end

end # time
println()
println("Total elapsed time: $elapsed_time seconds")

# # additional prints and analysis by Andrey:
println()
println("-------------------- output analysis --------------------")
if OPF_opt == 1
      println("OPF_opt = 1 (multi-period OPF)")
else
      println("OPF_opt = 0 (single-period SCACOPF)")
end
if Obj_f_opt == 0
      println("Obj_f_opt = 0 (total cost minimisation)")
elseif Obj_f_opt == 1
      println("Obj_f_opt = 1 (load curtailment optimisation)")
elseif Obj_f_opt == 2
      println("Obj_f_opt = 2 (total expected cost - stochastic optimisation)")
end
if Inv_opt == 0 
      println("Inv_opt = 0 (investments are added as input parameters)")
else
      println("Inv_opt = 1 (investments are explicitly formulated as variables)")
end
println("Objective value: ",JuMP.objective_value(model_name))
println("Max load P curtailment: ",maximum(active_load_curt[1]))
println("Max load Q curtailment: ",maximum(reactive_load_curt[1]))
if OPF_opt==0
      println("Number of contingencies considered = ",size(active_load_curt_c)[1])
      println("Max contingency load P curtailment: ",maximum(Iterators.flatten(active_load_curt_c)))
      println("Max contingency load Q curtailment: ",maximum(Iterators.flatten(reactive_load_curt_c)))
      # println("Thermal limits duals: [",minimum(values(s_res[:OPF_thermal_limit_max_dual_normal]))," : ",maximum(values(s_res[:OPF_thermal_limit_max_dual_normal])),"]")
      # println("Thermal limits contingency duals: [",minimum(values(s_res[:OPF_thermal_limit_max_dual_contin]))," : ",maximum(values(s_res[:OPF_thermal_limit_max_dual_contin])),"]")
end
# println("P power balance duals: [",minimum(values(s_res[:active_power_balance_normal_dual]))," : ",maximum(values(s_res[:active_power_balance_normal_dual])),"]")
# println("Q power balance duals: [",minimum(values(s_res[:reactive_power_balance_normal_dual]))," : ",maximum(values(s_res[:reactive_power_balance_normal_dual])),"]")
# if OPF_opt==0
#       println("P contingency power balance duals: [",minimum(values(s_res[:active_power_balance_contin_dual]))," : ",maximum(values(s_res[:active_power_balance_contin_dual])),"]")
#       println("Q contingency power balance duals: [",minimum(values(s_res[:reactive_power_balance_contin_dual]))," : ",maximum(values(s_res[:reactive_power_balance_contin_dual])),"]")
# end

println("P flex increase: [",minimum(flex_array_inc[1])," : ",maximum(flex_array_inc[1]),"]")
println("Q flex increase: [",minimum(flex_array_inc_q[1])," : ",maximum(flex_array_inc_q[1]),"]")
println("P flex decrease: [",minimum(flex_array_dec[1])," : ",maximum(flex_array_dec[1]),"]")
println("Q flex decrease: [",minimum(flex_array_dec_q[1])," : ",maximum(flex_array_dec_q[1]),"]")
if OPF_opt==0
      println("P flex contingency increase: [",minimum(Iterators.flatten(flex_array_contin_inc))," : ",maximum(Iterators.flatten(flex_array_contin_inc)),"]")
      println("Q flex contingency increase: [",minimum(Iterators.flatten(flex_array_contin_inc_q))," : ",maximum(Iterators.flatten(flex_array_contin_inc_q)),"]")
      println("P flex contingency decrease: [",minimum(Iterators.flatten(flex_array_contin_dec))," : ",maximum(Iterators.flatten(flex_array_contin_dec)),"]")
      println("Q flex contingency decrease: [",minimum(Iterators.flatten(flex_array_contin_dec_q))," : ",maximum(Iterators.flatten(flex_array_contin_dec_q)),"]")
end
println("Wind curtailment (pen_ws): ",value.(pen_ws))
if OPF_opt==0
      println("Wind contingency curtailment (pen_ws_c): ",value.(pen_ws_c))
end