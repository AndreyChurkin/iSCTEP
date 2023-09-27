#------read all data all at once from json file ---------------------------------
new_data = Dict()
open("data_preparation\\import_WP3.json", "r") do g
        global new_data
    new_data=JSON.parse(g)

end

# new_data["load_multiplier"] = 2 # testing the WP3 data inputs

#--------------upgrade the Smax of the lines as an output of EX plan----------
array_lines = deepcopy(array_lines_0) # set capacities back to initial values
global array_lines_reinf = deepcopy(array_lines_0) # write down only additional (new) capacities due to reinforcement
for l = 1:size(array_lines_reinf)[1]
    global array_lines_reinf[l].line_Smax_A = 0
end

for l in 1:nLines
    if new_data["ci"][1][l]!=0
        # cap_inc_factor = (array_lines[l].line_Smax_A + new_data["ci"][1][l]/sbase)/array_lines[l].line_Smax_A # - update for the PSCC paper - by how much the line is reinforced
        if Inv_opt == 0
            global array_lines[l].line_Smax_A = array_lines_0[l].line_Smax_A + new_data["ci"][1][l]/sbase 
        end

        global array_lines_reinf[l].line_Smax_A = new_data["ci"][1][l]/sbase

        # # activate to adjust the impedances as well:
        # array_lines[l].line_g = array_lines[l].line_g*cap_inc_factor
        # array_lines[l].line_b = array_lines[l].line_b*cap_inc_factor
        
    end
end

# println("line_smax_c:",line_smax_c)

#-------------set the limits for the flexible load separated for increase and decrease-------------
upper_flex_p_inc=ones(nFl,1)
upper_flex_p_dec=ones(nFl,1)
upper_flex_q_inc=ones(nFl,1)
upper_flex_q_dec=ones(nFl,1)
if nFl!=0
for  i in 1:nFl
    upper_flex_p_inc[i]=new_data["Pflex_inc"][1][nd_fl[i]]/sbase
    upper_flex_p_dec[i]=new_data["Pflex_dec"][1][nd_fl[i]]/sbase
    upper_flex_q_inc[i]=new_data["Qflex_inc"][1][nd_fl[i]]/sbase
    upper_flex_q_dec[i]=new_data["Qflex_dec"][1][nd_fl[i]]/sbase
end
end


#-----------look for any negative generators------------------
neg_gen_bus=[]
if haskey(new_data, "negGen")
    idx_neg=size(new_data["negGen"],1)
      for i in 1:idx_neg
      push!(neg_gen_bus, new_data["negGen"][i][1])
  end
end

new_gen_cost=new_data["gencost"]

OPF_opt=new_data["OPF_opt"]
# OPF_opt=1
nTP=[]
if OPF_opt==0
    nTP=1
elseif OPF_opt==1
    nTP=24
end

load_multiplier=new_data["load_multiplier"]
gen_multiplier =new_data["gen_multiplier"]


prof_ploads=load_multiplier*prof_ploads_0
prof_qloads=load_multiplier*prof_qloads_0

pg_max=gen_multiplier*pg_max_0
qg_max=gen_multiplier*qg_max_0

pg_min=gen_multiplier*pg_min_0
qg_min=gen_multiplier*qg_min_0
