# iSCTEP
**Interpretable Security-Constrained Transmission Expansion Planning**

This repository contains **i-SCTEP**, a tool for N-1 secure network planning that enables interpreting the value of flexibility (e.g., from energy storage systems) in terms of contributions to avoided load curtailment and total expected system cost reduction. Inspired by cooperative game theory, the tool ranks the contributions of flexibility providers and compares them against traditional line reinforcements. Specifically, the tool formulates a cooperative game among selected investment options (line reinforcements and flexibility providers) and iteratively solves a planning model to estimate the value of investments in different coalitions (combinations of investments). This information can be used by system planners to prioritise investments with higher contributions and synergistic capabilities.

At the core of **i-SCTEP** lies a nonlinear stochastic security-constrained optimal power flow (OPF) model developed by Mohammad Iman Alizadeh and Florin Capitanescu (Luxembourg Institute of Science and Technology) [1]. This model was improved and extended by Andrey Churkin (The University of Manchester) to include the coalitional analysis of investment options [2].

### MOTIVATING EXAMPLE:

To illustrate the principles of flexibility valuation in N-1 secure network planning, the tool is applied to a simple 5-bus system with 6 lines, 3 generators, two loads and one wind farm [1]. A single-line diagram of the system is presented below:

<img src="C5_scheme.png" alt="C5 scheme" width="500">

A set of 6 contingencies is considered, corresponding to the tripping of every line. The case is designed in a way that some of the post-contingency states will lead to load load curtailment.
To avoid potential load curtailment, it is necessary to upgrade the system and solve the security-constrained planning problem. It is assumed that the system planner has the following investment options: 1) each line can be reinforced by a maximum additional capacity of 100 MVA, 2) flexibility (e.g., energy storage systems) can be built at bus 1 and bus 2, with a maximum capacity of 100 MW.

Using traditional network planning models, the system planner can find a single optimal solution, e.g., a cost-minimising investment portfolio. However, a single solution is not sufficient to interpret the value of flexibility in the considered planning problem. To deal with planning uncertainties, the system planner needs to prioritise the investment options and address the following questions before accepting the optimal expansion plan. How do flexibility providers contribute to avoiding potential load curtailment and reducing the total expected system cost? How effective are flexibility investments compared to line reinforcement? Which investment options jointly contribute to the defined objectives and thus have the highest synergistic capabilities in SCTEP? 

To address these questions and provide additional information for the system planner, **i-SCTEP** tool formulates a cooperative game among the 8 investment options with 2<sup>8</sup>=256 possible coalitions. For each coalition, maximum avoided load curtailment and total expected cost reduction are estimated to characterise its value. Then, the marginal contributions of players (investment options) are calculated and the Shapley value is computed to represent the weighted average contribution to all possible coalitions. The results are presented below as violin plots showing the distribution of the players' marginal contributions:

<div style="display: flex; gap: 40px;">
    <img src="C5_violin_plots.png" alt="Violin plot 1" width="500">
    <img src="C5_violin_plots_cost.png" alt="Violin plot 2" width="500">
</div>

In this illustrative example, reinforcement of line 1-4 appears to be the best investment option with the highest synergistic capability, that is, the largest contributions in combination with other investments. Thus, this line should be given priority in the system expansion planning. A more detailed discussion of the results, as well as a larger case study, can be found in [2].

### RUNNING THE TOOL:

The tool has been developed and tested for Julia 1.6.1 programming language with JuMP 1.11.0 and Ipopt 3.14.4 solver.

There are many components, parameters and options of the tool, as explained below. As the tool interface is not yet automated, **iSCTEP** users will need to set the parameters manually, define the input data, and run the corresponding .jl files.

There are two main ways to run the simulations:
- Via **"main.jl"**, which solves a single optimisation model, e.g., corresponding to a security-constrained OPF. This option has no coalitional analysis of investments. However, it enables a thorough analysis of a specific network operation, its costs, load curtailment, impacts of contingencies and investments, etc.
- Via **"coalitional_analysis.jl"**, **"coalitional_analysis_UK.jl"**, or other dedicated scripts for coalitional analysis of specific case studies. This option requires defining N players of a cooperative game (investment options), for which a cooperative game with 2<sup>N</sup> coalitions will be considered. That is, **"main_iterative.jl"** will be called in a loop to estimate the value of each coalition. Then, the contributions of players to coalitions and the Shapley value are calculated.

There are several important parameters to modify the model:
- **"OPF_opt"** defines the system operation problem: **=0** sets a single-period security-constrained OPF model; **=1** sets a multi-period OPF model.
- **"Obj_f_opt"** defines the objective function: **=0** sets the total system cost minimisation for a single scenario; **=1** sets the minimisation of load curtailment in all scenarios and system states; **=2** sets the total expected system cost minimisation for all scenarios.
- **"Inv_opt"** specifies the way investment options are modelled: **=0** sets investments as parameters (i.e., fixed additional capacities); **=1** sets investments as variables in the optimisation model.
- **"use_trunc_coal_struct"** defines the coalitions to consider in the coalitional analysis: **=0** requires the full coalitional structure (2<sup>N</sup> coalitions) to be simulated; **=1** sets a truncated coalitional structure (only with coalitions of one player, N players, and N-1 players).

All of the above parameters are now defined within the scripts, e.g., in **"main.jl"** or **"coalitional_analysis.jl"**.

Finally, the input data and case studies are defined as follows:
- Folder **"/input data/"** contains cases in ODS format and data for generating scenarios, e.g., wind power profiles. The case for simulations is then defined in the scripts, for example: `filename = "input_data/C5.ods"`
- The number of scenarios is defined for each case study in the "Dimension" sheet of the .ODS files.
- Investment costs are defined in the scripts, for example: `lines_inv_cost = 5`
- The number of players (investment options), their names, capacity and location are defined in the scripts for coalitional analysis, for example:
`nPl = 8 # number of players`
`pl_titles = ["L1-2" "L1-3" "L1-4" "L2-5" "L3-4" "L4-5" "F1" "F2"]`
`if_pl_lines = [1 1 1 1 1 1 0 0] # define players: 1 = line, 0 = flexibility`
`pl_lines_numbers = [1 2 3 4 5 6] # number of each line player`
`pl_flex_numbers = [1 2] # bus of flexibility players`
`pl_capacity = [100 100 100 100 100 100 100 100]`
- Finally, the tool reads data from **"\data_preparation\import_WP3.json"** to define available investments and load multipliers. Scripts for coalitional analysis automatically generate this JSON file for each coalition. However, if using **"main.jl"**, users need to generate and update **"\data_preparation\import_WP3.json"** manually or using **"\data_preparation\json_creator.jl"**.

The simulation results can be saved in JLD or CSV formats by activating the corresponding commands in the scripts.

At the end of the scripts for coalitional analysis, there are commands for producing and saving the plots.

### REFERENCES:
[1] M. I. Alizadeh, M. Usman, and F. Capitanescu, “Envisioning security control in renewable dominated power systems through stochastic multiperiod AC security constrained optimal power flow,” International Journal of Electrical Power & Energy Systems, vol. 139, 2022

[2] A. Churkin, W. Kong, M. I. Alizadeh, F. Capitanescu, P. Mancarella, E. A. Martinez Cesena, "Interpreting the Value of Flexibility in AC Security-Constrained Transmission Expansion Planning via a Cooperative Game Framework," 2023, https://arxiv.org/abs/2310.03610
