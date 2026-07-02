# References

Consolidated bibliography for the [Bounds, Branches, and Feasibility](index.md) note and
its [Trusting the solver](solver_trust.md) capstone.
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
  Transactions on Smart Grid*, vol. 9, no. 2, pp. 953–962, 2018.
  [DOI](https://doi.org/10.1109/TSG.2016.2572060)
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
  easy to solve," *IEEE PES General Meeting*, 2012.
  [DOI](https://doi.org/10.1109/PESGM.2012.6345272)
- B. Kocuk, S. S. Dey, and X. A. Sun, "Inexactness of SDP relaxation and valid
  inequalities for optimal power flow" (two-bus characterization of the three
  approximation outcomes), *IEEE Transactions on Power Systems*, vol. 31, no. 1,
  pp. 642–651, 2016. [DOI](https://doi.org/10.1109/TPWRS.2015.2402640)
- Z. Yuan and M. Paolone, "Properties of convex optimal power flow model based on power
  loss relaxation" (objective-monotonicity ⇒ exactness), *Electric Power Systems
  Research*, 2020. [arXiv](https://arxiv.org/abs/1906.06105)
- J.-L. Lupien and A. Lesage-Landry, "Ex post conditions for the exactness of optimal
  power flow conic relaxations," 2023. [arXiv](https://arxiv.org/abs/2311.07781)
- D. K. Molzahn and I. A. Hiskens, "A survey of relaxations and approximations of the
  power flow equations," *Foundations and Trends in Electric Energy Systems*, vol. 4,
  no. 1–2, pp. 1–221, 2019. [DOI](https://doi.org/10.1561/3100000012)
- L. Bobo, A. Venzke, and S. Chatzivasileiadis, "Second-order cone relaxations of the
  optimal power flow for active distribution grids," 2020.
  [arXiv](https://arxiv.org/abs/2001.00898)

## Voltage collapse and loadability

- I. Dobson and L. Lu, "New methods for computing a closest saddle-node bifurcation and
  worst-case load power margin for voltage collapse," *IEEE Transactions on Power
  Systems*, vol. 8, no. 3, pp. 905–913, 1993. [DOI](https://doi.org/10.1109/59.260912)
- J. W. Simpson-Porco, F. Dörfler, and F. Bullo, "Voltage collapse in complex power
  grids," *Nature Communications*, vol. 7, 10790, 2016.
  [DOI](https://doi.org/10.1038/ncomms10790)
- T. Van Cutsem and C. Vournas, *Voltage Stability of Electric Power Systems*, Springer,
  1998 (canonical treatment of ZIP loads, the nose point, and continuation power flow).
  [DOI](https://doi.org/10.1007/978-0-387-75536-6)

## Computational complexity of AC OPF

- K. Lehmann, A. Grastien, and P. Van Hentenryck, "AC-feasibility on tree networks is
  NP-hard," *IEEE Transactions on Power Systems*, vol. 31, no. 1, pp. 798–801, 2016.
  [DOI](https://doi.org/10.1109/TPWRS.2015.2407363) ·
  [arXiv](https://arxiv.org/abs/1410.8253)
- D. Bienstock and A. Verma, "Strong NP-hardness of AC power flows feasibility,"
  *Operations Research Letters*, vol. 47, no. 6, pp. 494–501, 2019.
  [DOI](https://doi.org/10.1016/j.orl.2019.08.009) ·
  [arXiv](https://arxiv.org/abs/1512.07315)

## Global optimization and optimality certificates

- D. K. Molzahn and I. A. Hiskens, "Moment-based relaxation of the optimal power flow
  problem" (Lasserre / moment SDP hierarchy), *Power Systems Computation Conference
  (PSCC)*, 2014. [arXiv](https://arxiv.org/abs/1312.1992)
- C. Coffrin, H. L. Hijazi, and P. Van Hentenryck, "The QC relaxation: a theoretical and
  computational study on optimizing optimal power flow," *IEEE Transactions on Power
  Systems*, vol. 31, no. 4, pp. 3008–3018, 2016.
  [DOI](https://doi.org/10.1109/TPWRS.2015.2463111) ·
  [arXiv](https://arxiv.org/abs/1502.07847)
- H. Nagarajan, M. Lu, S. Wang, R. Bent, and K. Sundar, "An adaptive, multivariate
  partitioning algorithm for global optimization of nonconvex programs" (Alpine.jl spatial
  branch-and-bound), *Journal of Global Optimization*, vol. 74, pp. 639–675, 2019.
  [DOI](https://doi.org/10.1007/s10898-018-00734-1) ·
  [arXiv](https://arxiv.org/abs/1707.02514)
- S. Gopinath, H. L. Hijazi, T. Weisser, H. Nagarajan, M. Yetkin, K. Sundar, and
  R. W. Bent, "Proving global optimality of ACOPF solutions" (SDP bound tightening with
  valid cuts; closes gaps on PGLib), *Electric Power Systems Research*, vol. 189, 106688,
  2020. [DOI](https://doi.org/10.1016/j.epsr.2020.106688) ·
  [arXiv](https://arxiv.org/abs/1910.03716)

## Solver behaviour, constraint qualifications, and insolvability

- A. Wächter and L. T. Biegler, "On the implementation of an interior-point filter
  line-search algorithm for large-scale nonlinear programming" (Ipopt; feasibility
  restoration phase), *Mathematical Programming*, vol. 106, no. 1, pp. 25–57, 2006.
  [DOI](https://doi.org/10.1007/s10107-004-0559-y)
- O. Hinder and Y. Ye, "A one-phase interior point method for nonconvex optimization"
  (first-order certificates of local infeasibility, local optimality, or unboundedness),
  2018. [arXiv](https://arxiv.org/abs/1801.03072)
- A. Hauswirth, S. Bolognani, G. Hug, and F. Dörfler, "Generic existence of unique
  Lagrange multipliers in AC optimal power flow" (LICQ holds generically, via differential
  topology), *IEEE Control Systems Letters*, vol. 2, no. 4, pp. 791–796, 2018.
  [DOI](https://doi.org/10.1109/LCSYS.2018.2849657) ·
  [arXiv](https://arxiv.org/abs/1806.06615)
- G. Haeser, O. Hinder, and Y. Ye, "On the behavior of Lagrange multipliers in convex and
  non-convex infeasible interior point methods" (LICQ/MFCQ and multiplier boundedness),
  *Mathematical Programming*, vol. 186, pp. 257–288, 2021.
  [DOI](https://doi.org/10.1007/s10107-019-01454-4) ·
  [arXiv](https://arxiv.org/abs/1707.07327)
- D. K. Molzahn, B. C. Lesieutre, and C. L. DeMarco, "A sufficient condition for power
  flow insolvability with applications to voltage stability margins" (Jacobian
  singularity and zero-voltage degeneracy), *IEEE Transactions on Power Systems*, 2013.
  [PDF](https://molzahn.github.io/pubs/molzahn_lesieutre_demarco-pfcondition.pdf)
- A. U. Raghunathan and L. T. Biegler, "An ℓ1 exact penalty-barrier phase for degenerate
  nonlinear programming problems in Ipopt" (redundant / dependent constraints and LICQ
  recovery), *IFAC World Congress*, 2020.
  [Link](https://www.sciencedirect.com/science/article/pii/S2405896320324071)
- D. Ralph and S. J. Wright, "Superlinear convergence of an interior-point method despite
  dependent constraints," *Mathematics of Operations Research*, vol. 25, no. 2,
  pp. 179–194, 2000. [DOI](https://doi.org/10.1287/moor.25.2.179.12227)
- J. Hörsch, H. Ronellenfitsch, D. Witthaut, and T. Brown, "Linear optimal power flow
  using cycle flows" (linear dependence of nodal KCL and the slack-bus equation),
  *Electric Power Systems Research*, 2018. [arXiv](https://arxiv.org/abs/1704.01881)

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
