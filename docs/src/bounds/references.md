# References

Consolidated bibliography for the [Bounds, Branches, and Feasibility](index.md) note.
Inline citations throughout the note link directly to the source; this page is the
formal list.

## Power flow solvability, uniqueness, and the high-voltage solution

- S. Bolognani and S. Zampieri, "On the existence and linear approximation of the power
  flow solution in power distribution networks," *IEEE Transactions on Power Systems*,
  vol. 31, no. 1, pp. 163–172, 2016.
  [DOI](https://doi.org/10.1109/TPWRS.2015.2395452)
- J. W. Simpson-Porco, "A theory of solvability for lossless power flow equations —
  Part I: Fixed-point power flow," and "Part II: Conditions for radial networks,"
  *IEEE Transactions on Control of Network Systems*, vol. 5, no. 3, 2018.
  [arXiv (Part I)](https://arxiv.org/abs/1701.02045)
- K. Dvijotham, E. Mallada, and J. W. Simpson-Porco, "High-voltage solution in radial
  power networks: existence, properties, and equivalent algorithms," *IEEE Control
  Systems Letters*, vol. 1, no. 2, pp. 322–327, 2017.
  [arXiv](https://arxiv.org/abs/1706.05290)
- C. Wang, A. Bernstein, J.-Y. Le Boudec, and M. Paolone, "Explicit conditions on
  existence and uniqueness of load-flow solutions in distribution networks," *IEEE
  Transactions on Smart Grid*, vol. 9, no. 2, 2018.
  [DOI](https://doi.org/10.1109/TSG.2016.2588541)
- A. Bernstein, C. Wang, E. Dall'Anese, J.-Y. Le Boudec, and C. Zhao, "Load flow in
  multiphase distribution networks: existence, uniqueness, non-singularity and linear
  models," *IEEE Transactions on Power Systems*, 2018.
  [DOI](https://doi.org/10.1109/TPWRS.2018.2823277)

## Convex relaxations and exactness

- S. H. Low, "Convex relaxation of optimal power flow — Part I: Formulations and
  equivalence; Part II: Exactness," *IEEE Transactions on Control of Network Systems*,
  vol. 1, no. 1–2, 2014. [DOI (Part II)](https://doi.org/10.1109/TCNS.2014.2323634)
- L. Gan, N. Li, U. Topcu, and S. H. Low, "Exact convex relaxation of optimal power flow
  in radial networks," *IEEE Transactions on Automatic Control*, vol. 60, no. 1, 2015.
  [arXiv](https://arxiv.org/abs/1311.7170)
- S. Sojoudi and J. Lavaei, "Physics of power networks makes hard optimization problems
  easy to solve," *IEEE PES General Meeting / Allerton*, 2012.
  [DOI](https://doi.org/10.1109/Allerton.2012.6483445)
- R. Madani, S. Sojoudi, and J. Lavaei, "Inexactness of SDP relaxation and valid
  inequalities for optimal power flow" (two-bus characterization of the three
  approximation outcomes), *IEEE Transactions on Power Systems*, vol. 30, no. 1, 2015.
  [DOI](https://doi.org/10.1109/TPWRS.2014.2387234)
- Z. Yuan and M. Paolone, "Properties of convex optimal power flow model based on power
  loss relaxation" (objective-monotonicity ⇒ exactness), *Electric Power Systems
  Research*, 2020. [arXiv](https://arxiv.org/abs/1906.06105)
- J.-L. Lupien and A. Lesage-Landry, "Ex post conditions for the exactness of optimal
  power flow conic relaxations," 2023. [arXiv](https://arxiv.org/abs/2311.07781)
- D. K. Molzahn and I. A. Hiskens, "A survey of relaxations and approximations of the
  power flow equations," *Foundations and Trends in Electric Energy Systems*, 2019.
- L. Bobo, A. Venzke, and S. Chatzivasileiadis, "Second-order cone relaxations of the
  optimal power flow for active distribution grids," 2020.
  [arXiv](https://arxiv.org/abs/2001.00898)

## Voltage collapse and loadability

- I. Dobson and L. Lu, "New methods for computing a closest saddle-node bifurcation and
  worst-case load power margin for voltage collapse," *IEEE Transactions on Power
  Systems*, 1993. [DOI](https://doi.org/10.1109/9.222302)
- J. W. Simpson-Porco, F. Dörfler, and F. Bullo, "Voltage collapse in complex power
  grids," *Nature Communications*, vol. 7, 10790, 2016.
  [DOI](https://doi.org/10.1038/ncomms10790)
- T. Van Cutsem and C. Vournas, *Voltage Stability of Electric Power Systems*, Springer,
  1998 (canonical treatment of ZIP loads, the nose point, and continuation power flow).
  [DOI](https://doi.org/10.1007/978-0-387-75536-6)

## Software and the PowerModels ecosystem

- C. Coffrin, R. Bent, K. Sundar, Y. Ng, and M. Lubin, "PowerModels.jl: an open-source
  framework for exploring power flow formulations," *PSCC*, 2018.
  [DOI](https://doi.org/10.23919/PSCC.2018.8442948)
- D. M. Fobes, S. Claeys, F. Geth, and C. Coffrin, "PowerModelsDistribution.jl: an
  open-source framework for exploring distribution power flow formulations," *Electric
  Power Systems Research*, 2020. [arXiv](https://arxiv.org/abs/2004.10081)

## Optimization model debugging

- JuMP, "Debugging" tutorial and "Solutions" manual.
  [Debugging](https://jump.dev/JuMP.jl/stable/tutorials/getting_started/debugging/) ·
  [Solutions](https://jump.dev/JuMP.jl/stable/manual/solutions/)
- E. Kalvelagen, "The best way to debug infeasible models," *Yet Another Math
  Programming Consultant*, 2018.
  [Link](http://yetanothermathprogrammingconsultant.blogspot.com/2018/08/the-best-way-to-debug-infeasible-models.html)
- YALMIP, "Infeasible or unbounded" and "Debugging unbounded models."
  [1](https://yalmip.github.io/infeasibleorunbounded) ·
  [2](https://yalmip.github.io/debuggingunbounded)
- GAMS, "Execution errors and performance."
  [Link](https://www.gams.com/latest/docs/UG_ExecErrPerformance.html)
- Pyomo, "Model debugging."
  [Link](https://pyomo.readthedocs.io/en/stable/model_debugging/index.html)
- AIMMS, "Debug infeasible or unbounded results."
  [Link](https://how-to.aimms.com/Articles/136/136-Infeasible-Unbounded.html)

!!! note "Citation hygiene"
    Volume/issue numbers are given where confirmed. Please verify exact page numbers and
    the Low / Simpson-Porco two-part details against the publisher before pinning these
    in a released version of the docs.
