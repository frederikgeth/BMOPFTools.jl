# [Bibliography](@id refs)

References cited by number across this documentation.

1. M. Deakin, A. Pandey, F. Geth, *Mathematical Model and Data Model for
   Up-To-Four-Wire Distribution System OPF*, IEEE Task Force on
   Benchmarking Multiconductor OPF for Distribution Systems, draft V0.2, 2026.
2. F. Geth, A. C. Chapman, R. Heidari, J. Clark, "Considerations and design
   goals for unbalanced optimal power flow benchmarks," *Electric Power
   Systems Research* 235 (2024) 110646.
3. F. Geth, F. Pacaud, R. Heidari, "Solving Three-Phase Distribution OPF
   with Nonlinear Programming," *PSCC 2026*, Limassol.
4. J. R. Carson, "Wave propagation in overhead wires with ground return,"
   *Bell System Technical Journal* 5 (1926) 539–554.
5. W. H. Kersting, *Distribution System Modeling and Analysis*, CRC Press, 2002.
6. S. Claeys, F. Geth, G. Deconinck, "Optimal power flow in four-wire
   distribution networks: Formulation and benchmarking," *Electric Power
   Systems Research* 213 (2022) 108522.
7. F. Geth, R. Heidari, A. Koirala, "Computational analysis of impedance
   transformations for four-wire power networks with sparse neutral
   grounding," *Proc. ACM e-Energy '22*, 2022, 105–113.
8. R. Heidari, F. Geth, S. Claeys, *Four-wire low voltage power network
   dataset*, CSIRO Data Collection, 2024, doi:10.25919/jaae-vc35; original
   data: ENWL *Low Voltage Network Solutions* project (LCNF closedown
   report, 2014); cable impedances: A. J. Urquhart, M. Thomson, *Cable
   Impedance Data*, figshare, 2019.
9. R. C. Dugan, T. E. McDermott, "An open source platform for collaborating
   on smart grid research," *Proc. IEEE PES General Meeting*, 2011; EPRI
   OpenDSS documentation, incl. *Modeling Regulators as Autotransformers*.
10. F. Dörfler, F. Bullo, "Kron reduction of graphs with applications to
    electrical networks," *IEEE Trans. Circuits and Systems I* 60 (2013)
    150–163.
11. F. Zhang (ed.), *The Schur Complement and Its Applications*, Springer,
    2005 (incl. D. Carlson, T. L. Markham, "Schur complements of diagonally
    dominant matrices," *Czech. Math. J.* 29 (1979) for the M-matrix
    closure).
12. M. Bazrafshan, N. Gatsis, "Comprehensive modeling of three-phase
    distribution systems via the bus admittance matrix," *IEEE Trans. Power
    Systems* 33 (2018) 2015–2029.
13. S. Babaeinejadsarookolaee et al., "The power grid library for
    benchmarking AC optimal power flow algorithms," arXiv:1908.02788, 2019.
14. F. Geth, M. Vanin, D. Van Hertem, "Data quality challenges in existing
    distribution network datasets," *CIRED 2023*, Rome.
15. D. M. Fobes, S. Claeys, F. Geth, C. Coffrin, "PowerModelsDistribution.jl:
    An open-source framework for exploring distribution power flow
    formulations," *Electric Power Systems Research* 189 (2020) 106664;
    arXiv:2004.10081.
16. R. C. Dugan, "A Perspective on Transformer Modeling for Distribution
    System Analysis," *Proc. IEEE PES General Meeting*, 2003, pp. 114–119
    (the case for solving in actual values rather than per-unit; cites
    H. W. Dommel, *EMTP Theory Book*, 2nd ed., App. IV, on per-unit
    obsolescence for computer solution of unbalanced networks).
17. W. H. Kersting, "The Whys of Distribution System Analysis," *Proc. IEEE
    Rural Electric Power Conference (REPC)*, 2010 (why the transmission
    assumptions of transposed lines and balanced loading — and hence the
    positive-sequence/symmetrical-component model — do not transfer to
    distribution; worked IEEE 13-node examples of non-transposed-line and
    neutral/ground-current effects).
18. A. Wächter, L. T. Biegler, "On the implementation of an interior-point
    filter line-search algorithm for large-scale nonlinear programming,"
    *Mathematical Programming* 106 (2006) 25–57 (Ipopt; the solver's
    initialization, barrier updates and stopping tests are scale-sensitive,
    and it applies gradient-norm scaling because good scaling cannot be
    inferred in general).
19. J. D. Hogg, J. A. Scott, *On the effects of scaling on the performance
    of Ipopt*, STFC Rutherford Appleton Laboratory technical report
    RAL-TR-2013-P-001, 2013; arXiv:1301.7283 (the benefit of scaling a
    nonlinear program is problem-dependent, not universal).
20. S. A. Sadat, K. Kim, "Numerical Performance of Different Formulations for
    Alternating Current Optimal Power Flow," *Proc. IEEE PES ISGT*, 2021;
    arXiv:2107.07700 (IPM numerical performance on AC-OPF is strongly
    formulation-dependent).
21. M. D. Wilkinson et al., "The FAIR Guiding Principles for scientific data
    management and stewardship," *Scientific Data* 3 (2016) 160018 (Interoperable
    and Reusable data require shared vocabularies and recorded provenance, not
    raw dumps).
22. H. Wickham, "Tidy Data," *Journal of Statistical Software* 59 (10) (2014)
    1–23 (data is usually organized for ease of entry rather than analysis;
    standardizing the mapping of semantics to representation is what makes
    reliable, composable tooling possible).
23. IEC 61968-11:2013, *Application integration at electric utilities — System
    interfaces for distribution management — Part 11: Common Information Model
    (CIM) extensions for distribution*; the network "wires model" represents
    connectivity through explicit `Terminal` and `ConnectivityNode` objects (the
    structure OpenDSS leaves implicit). See also the OpenDSS CIM100 export of
    ref. 9 above.
24. F. Wiese et al., "Open Power System Data — Frictionless data for electricity
    system modelling," *Applied Energy* 236 (2019) 401–409 (a validated,
    schema-checked, reproducible path from raw data to results for energy-system
    modeling).
25. L. Moreau, P. Missier (eds.), *PROV-DM: The PROV Data Model*, W3C
    Recommendation, 2013 (provenance as the mechanism that makes a non-identity
    transformation trustworthy; validity is itself defined via a normalization
    process).
26. D. K. Molzahn, B. C. Lesieutre, C. L. DeMarco, "Approximate Representation of
    ZIP Loads in a Semidefinite Relaxation of the OPF Problem," *IEEE Trans.
    Power Syst.* 29 (4) (2014) 1864–1865 (a constant-impedance load is a shunt
    admittance `Sⱼ/|Vⱼ|²`; the load/shunt identity is a modeling choice, not a
    physical one).
27. H. J. Kim et al., "A Comprehensive Review of Practical Issues for
    Interoperability Using the Common Information Model in Smart Grids,"
    *Energies* 13 (6) (2020) 1435 (CIM as an asset-first, object-identity model
    for semantic interoperability and data exchange).
28. B. Bahrani et al., "Grid-Forming Inverter-Based Resource Research Landscape:
    Understanding the Key Assets for Renewable-Rich Power Systems," *IEEE Power &
    Energy Magazine* 22 (2) (2024) 18–29 (IBR-based resources as a distinct
    asset class from synchronous generators — capability-limited, inertia-free,
    control-defined).
29. R. Yan, Y. Li, T. K. Saha, L. Wang, M. I. Hossain, "Modeling and Analysis of
    Open-Delta Step Voltage Regulators for Unbalanced Distribution Network With
    Photovoltaic Power Generation," *IEEE Transactions on Smart Grid* 9 (3)
    (2018) 2224–2234, doi:10.1109/TSG.2016.2609440.
