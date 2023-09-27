elapsed_time = @elapsed begin

using JuMP,OdsIO,MathOptInterface,Dates,LinearAlgebra
using Ipopt, JSON
# using BenchmarkTools
# using CPLEX
# using SCIP       # It is not useful for our purpose. Mianly deals with the feasibility problem.
# using AmplNLWriter
# using Cbc

#-------------------Accessing current folder directory--------------------------
show(pwd());
cd(dirname(@__FILE__))
println("")
show(pwd());

# files = cd(readdir, string(pwd(),"\\Network_Data"))
#--------------------Read Data from the Excel file------------------------------
# @time begin

# filename = "input_data/case_template_port_modified_R1.ods"
# filename = "input_data/case60_bus_new_wind.ods"
# filename = "input_data/C60.ods"
# filename = "input_data/C5.ods"
# filename = "input_data/C5_RES.ods"
# filename = "input_data/HR.ods"
# filename = "input_data/PT.ods"
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



# filename = "input_data/case5_bus_new.ods"
filename_scenario= "input_data/scenario_gen.ods"
# filename_scenario= "scenario_gen.ods"
# filename = "case_34_baran_modf.ods"
include("data_preparation/data_types.jl")      # Reading the structure of network related fields

include("data_preparation/data_types_contingencies.jl")

include("data_preparation/data_reader.jl")     # Function setting the data corresponding to each network quantity

include("data_preparation/interface_excel.jl") # Program saving all the inforamtion related to each entity of a power system

global array_lines_0 = deepcopy(array_lines) # initial capacity of lines read from ODS

lines_inv_cost = 5 # reinforcement costs $/MWh
lines_inv_costs = ones(nLines)*lines_inv_cost


#-----------functions---------------------
include("functions/network_topology_functions.jl")

# include("data_preparation/json_interface_import.jl")

include("functions/AC_SCOPF_functions.jl")


#----------------------- Formatting of Network Data ----------------------------
include("data_preparation/contin_scen_arrays.jl")

include("data_preparation/node_data_func.jl")

global prof_ploads_0 = deepcopy(prof_ploads) # initial data from ODS
global prof_qloads_0 = deepcopy(prof_qloads) # initial data from ODS
global pg_max_0 = deepcopy(pg_max) # initial data from ODS
global qg_max_0 = deepcopy(qg_max) # initial data from ODS
global pg_min_0 = deepcopy(pg_min) # initial data from ODS
global qg_min_0 = deepcopy(qg_min) # initial data from ODS

# # # include("data_preparation\\json_generator.jl")
include("data_preparation/json_interface_import.jl") # <--- Function can be moved to network_topology_functions.jl

# # re-include functions to consider new data:
include("functions/AC_SCOPF_functions.jl")
include("data_preparation/contin_scen_arrays.jl")
include("data_preparation/node_data_func.jl")




show("Initial functions are compiled. ")


    # AC_SCOPF = direct_model(Ipopt.Optimizer, add_bridges=false)
    AC_SCOPF = Model(Ipopt.Optimizer)
#     AC_SCOPF = Model()
    model_name=AC_SCOPF
    JuMP.bridge_constraints(model_name)=false


    model_name=AC_SCOPF


## Activate to select a specific hour (not hour #1) for SCOPF:
# if OPF_opt==0
#       prof_ploads = prof_ploads[:,19] 
#       prof_qloads = prof_qloads[:,19] 
# end

(model_name,output)=SP_SCOPF_or_MP_OPF(OPF_opt)

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
elseif OPF_opt == 0
      println("OPF_opt = 0 (single-period SCACOPF)")
elseif Obj_f_opt == 2
      println("Obj_f_opt = 2 (total expected cost - stochastic optimisation)")
end
if Obj_f_opt == 0
      println("Obj_f_opt = 0 (total cost minimisation)")
elseif Obj_f_opt == 1
      println("Obj_f_opt = 1 (load curtailment optimisation)")
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