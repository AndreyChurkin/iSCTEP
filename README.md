# iSCTEP
**Interpretable Security-Constrained Transmission Expansion Planning**

This repository contains **i-SCTEP**, a tool for N-1 secure network planning that enables interpreting the value of flexibility (e.g., from energy storage systems) in terms of contributions to avoided load curtailment and total expected system cost reduction. Inspired by cooperative game theory, the tool ranks the contributions of flexibility providers and compares them against traditional line reinforcements. This information can be used by system planners to prioritise investments with higher contributions and synergistic capabilities.

At the core of **i-SCTEP** lies a nonlinear stochastic security-constrained optimal power model developed by Mohammad Iman Alizadeh and Florin Capitanescu (Luxembourg Institute of Science and Technology) [1]. This model was improved and extended by Andrey Churkin (The University of Manchester) to include the coalitional analysis of investment options [2].

### MOTIVATING EXAMPLE:

Consider a .....

To illustrate the principles of flexibility valuation in SCTEP, the developed tool is first applied to a simple 5-bus system with 6 lines, as shown by its single-line diagram in ..... This system has been originally introduced in ..... to test AC SCOPF models. There are three generators, each with a maximum capacity of 1500 MW and 750 MVar, supplying two loads (demand of 1100 MW and 400 MVAr at bus 1 and demand of 500 MW and 200 MVAr at bus 2). 

A set of 6 contingencies is considered, corresponding to the tripping of every line (N-1 conditions).

<img src="C5_scheme.png" alt="C5 scheme" width="500">

<div style="display: flex; gap: 40px;">
    <img src="C5_violin_plots.png" alt="Image 1" width="500">
    <img src="C5_violin_plots_cost.png" alt="Image 2" width="500">
</div>


### RUNNING THE TOOL:



### REFERENCES:
[1] M. I. Alizadeh, M. Usman, and F. Capitanescu, “Envisioning security control in renewable dominated power systems through stochastic multiperiod AC security constrained optimal power flow,” International Journal of Electrical Power & Energy Systems, vol. 139, 2022

[2] ... reference to be added...
