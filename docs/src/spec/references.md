# References and further reading

This specification stands on a large body of work in distribution-system modelling and
optimal power flow. The lists below point to the textbooks that develop the underlying
physics and the papers this model builds on directly. This is a *reference* page — it
introduces no model content.

## Textbooks

Distribution-system modelling (component models, Carson/Kron impedance, unbalanced
analysis):

- **W. H. Kersting**, *Distribution System Modeling and Analysis*, CRC Press (4th ed.,
  2017). The standard reference for line/cable impedance (Carson's equations, Kron
  reduction), transformer connections, and unbalanced power flow — the physics behind
  the [line](line.md), [impedance-derivation](impedance.md), and
  [transformer](transformer.md) pages.
- **T. A. Short**, *Electric Power Distribution Handbook*, CRC Press (2nd ed., 2014). A
  practical, equipment-oriented companion covering feeders, grounding, and protection.
- **R. C. Dugan, M. F. McGranaghan, S. Santoso, H. W. Beaty**, *Electrical Power Systems
  Quality*, McGraw-Hill (3rd ed., 2012). Background on unbalance, harmonics, and the
  power-quality phenomena that motivate conductor-level modelling. See also OpenDSS
  (Dugan/EPRI), the reference implementation this spec is validated against.

Optimal power flow and its mathematics:

- **S. H. Low**, *Power System Analysis: Analytical Tools and Structural Properties*
  (forthcoming graduate textbook). A rigorous, notation-first treatment of network models and OPF;
  freely available on registration at
  [netlab.caltech.edu/book_reg](https://netlab.caltech.edu/book_reg/). Its complex
  stacked-vector style is close to the [notation](notation.md) used here.
- **S. H. Low**, "Convex Relaxation of Optimal Power Flow, Parts I & II," *IEEE Trans.
  Control of Network Systems*, 2014. Foundational for the relaxations that lift the
  current–voltage formulation used here to power/lifted-voltage spaces.

### Accessible introductions and lecture notes

Approachable complements to the textbooks above for readers getting into distribution
networks — and especially for building intuition about **transformer loss models** —
where Steven Low's book covers the mathematics underneath:

- **Z. Wang**, distribution-systems course notes, Iowa State University:
  [Introduction to Distribution Systems](https://wzy.ece.iastate.edu/Courses/EE455/01%20EE455%20Introduction%20to%20Distribution%20Systems.pdf)
  (EE455),
  [Distribution System Transformers](https://wzy.ece.iastate.edu/Courses/EE555/Distribution%20System%20Transformers.pdf)
  (EE555 — connections and loss models), and
  [Real Distribution System Modeling and Analysis](https://wzy.ece.iastate.edu/PPT/EE653%20Real%20Distribution%20System%20Modeling%20and%20Analysis.pdf)
  (EE653). Clear, worked treatments of feeder components and how transformer losses map
  onto the equivalent circuit.
- **S. Claeys, G. Deconinck, F. Geth**, "Decomposition of n-winding transformers for
  unbalanced optimal power flow," *IET Generation, Transmission & Distribution*
  **14**(24):5961–5969, 2020,
  [doi:10.1049/iet-gtd.2020.0776](https://doi.org/10.1049/iet-gtd.2020.0776) — a useful
  reference for conceptualising the
  [transformer loss model](transformer.md#The-loss-equivalent-circuit).

## Foundational papers for this model

The four-wire current–voltage (IVR-EN) formulation, its benchmarking, and the device
models:

- **S. Claeys et al.**, "Optimal power flow in four-wire distribution networks:
  Formulation and benchmarking," *Electric Power Systems Research*, 2022. The four-wire
  OPF formulation this specification extends.
- **D. M. Fobes, S. Claeys, F. Geth, C. Coffrin**, "PowerModelsDistribution.jl: An
  open-source framework for exploring distribution power flow formulations," *Electric
  Power Systems Research*, 2020. The `IVRENPowerModel` lineage of the OPF engine.
- **F. Geth, H. Ergun**, "Real-Value Power-Voltage formulations of, and bounds for,
  three-wire unbalanced optimal power flow," 2023. The real-valued bound machinery
  behind the [engineering bounds](bus.md#Engineering-bounds).
- **F. Geth et al.**, "Considerations and design goals for unbalanced optimal power flow
  benchmarks," *Electric Power Systems Research*, 2024. The benchmarking philosophy
  behind this Task Force effort.
- **R. Heidari, F. Geth**, "Improved algebraic inverter modeling for four-wire power
  flow optimization," *Electric Power Systems Research*, 2024. The inverter modelling
  behind the [IBR](ibr.md) page (including the shared-DC-link STATCOM coupling).
- **R. C. Dugan**, "A perspective on transformer modeling for distribution system
  analysis," *IEEE PES General Meeting*, 2003. Background for the
  [transformer](transformer.md) winding models and grounding conventions.
- **R. Yan, Y. Li, T. K. Saha, L. Wang, M. I. Hossain**, "Modeling and Analysis of
  Open-Delta Step Voltage Regulators for Unbalanced Distribution Network With
  Photovoltaic Power Generation," *IEEE Transactions on Smart Grid*
  **9**(3):2224–2234, 2018,
  [doi:10.1109/TSG.2016.2609440](https://doi.org/10.1109/TSG.2016.2609440). The
  common-neutral open-delta step-voltage-regulator model behind the
  [regulator](regulator.md) page (`open_delta_regulator`).

## Benchmark libraries and test systems

- **S. Babaeinejadsarookolaee et al.**, "The Power Grid Library for benchmarking AC
  optimal power flow algorithms" (PGLib-OPF), 2019. The transmission-side, positive-
  sequence analogue of what this Task Force provides for unbalanced distribution.
- **K. P. Schneider et al.**, "Analytic Considerations and Design Basis for the IEEE
  Distribution Test Feeders," *IEEE Trans. Power Systems*, 2018. The IEEE Distribution
  Test Feeder Working Group's library (including the 8500-node feeder).

## Tools

- **OpenDSS** (EPRI) — the distribution power-flow reference this specification's
  implementation is validated against.
- **PowerModelsDistribution.jl** — the Julia framework whose `IVRENPowerModel` inspired
  this formulation.
- **BMOPFTools.jl** — the implementation this specification is sourced from.
