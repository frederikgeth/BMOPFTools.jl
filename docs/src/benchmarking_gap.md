# Why benchmarks matter: the 80% problem

[Positioning & ecosystem](positioning.md) describes *what* is missing in
distribution optimization — shared benchmark cases and standardized problem
specifications. This page makes the argument for *why* that gap matters: it
misleads algorithmic research, it breaks replication, and it explains why
distribution utilities remain unconvinced by much of the academic literature.
The perspective taken here is deliberately industry-first: utilities are
**right** to insist on reliable, scalable, generic, replicable solutions, and
the research community has so far struggled to deliver them.

## The industry bar

A distribution utility operating thousands of feeders cannot adopt a
technology that works for *most* of them. Two failure modes recur:

- **Works for 80% of the networks.** A method developed and tested on
  balanced, three-wire, radial, wye-connected test cases silently excludes
  the feeders that don't fit the template: four-wire multi-grounded
  construction, delta-connected and split-phase (center-tapped) transformers,
  single-wire earth-return (SWER) lines, meshed and looped LV areas,
  regulators mid-feeder, secondary networks. These are not exotica — they are
  the standard construction practice of entire regions. A tool that cannot
  ingest them is not 80% useful to the utility; it is a second parallel
  workflow, which is to say, a cost.

- **Works 80% of the time.** Linearizations and relaxations of the power flow
  equations are typically most accurate near the nominal operating point and
  degrade under heavy loading and large voltage deviations — see e.g. the
  premise of ongoing work on improving LinDistFlow under stressed conditions
  [[8]](@ref refs-benchmarking). But peak events are precisely when the utility needs the
  answer: hosting-capacity limits, operating envelopes, and thermal/voltage
  constraint management all bind at the extremes, not at the average. An
  approximation that is excellent on the 80% of hours when nothing binds and
  unreliable during the events that motivated the study has its error budget
  exactly backwards.

Neither failure mode is visible in a paper that reports results on a small,
balanced, lightly-stressed test case. Both are immediately visible to the
engineer asked to deploy the method.

## How the gap misleads research

**Unexpressive datasets select for the wrong algorithms.** If the shared test
cases lack neutrals, mutual coupling, transformer connection diversity, or
realistic loading, then methods are ranked by their performance on a problem
class that is *easier* than the real one. Kron-reduced three-wire models
introduce quantifiable error relative to explicit four-wire models
[[9]](@ref refs-benchmarking); simplification choices in LV modeling — cable impedances,
neutral and grounding connectivity, time resolution — materially change
results [[11]](@ref refs-benchmarking). The IEEE distribution test feeders were created to
verify the correctness of power-flow software [[2]](@ref refs-benchmarking), and the working
group itself later documented each feeder's design basis so researchers could
judge whether their use is appropriate [[3]](@ref refs-benchmarking) — they were never
designed as optimization benchmarks, yet they carry much of that load today.
A 2017 review of publicly available US test feeders concluded plainly that
"there is a shortage of realistic test systems that are publicly available"
for algorithm development [[4]](@ref refs-benchmarking).

The same dynamic has reappeared in machine learning for OPF: training and
evaluation sets sampled narrowly around nominal load make learned methods
look far better than they are, and "a lack of disciplined dataset creation
and benchmarking prohibits useful comparison among approaches in the
literature" [[13]](@ref refs-benchmarking); results turn out to be highly sensitive to
environment and sampling design [[14]](@ref refs-benchmarking).

**Unstandardized problem specifications break replication.** Even when two
papers use "the same" feeder, they rarely solve the same problem: bounds
differ, objectives differ, the treatment of the neutral, the source, the
transformer model, and the load model all differ — usually implicitly. The
IEEE PES task force behind PGLib-OPF formed for exactly this reason on the
transmission side: "it is often difficult to directly compare AC-OPF
benchmarking studies due to subtle differences in the AC-OPF problem
formulation as well as the network, generation, and loading data used"
[[1]](@ref refs-benchmarking). Distribution is strictly worse off: the modeling space is
larger (phases, wires, grounding, connections), and no PGLib-equivalent
exists. When context cannot be unambiguously established, a reported result
is not evidence — it is an anecdote.

**The consequence is a credibility gap, not just an inconvenience.** The
ARPA-E Grid Optimization Competition states the problem in its own
motivation: "The vast majority of reports only test new algorithms on either
relatively small-scale power network models, which often must be heavily
modified …, or on proprietary datasets that inherently cannot be released
for wide-spread performance testing" [[6]](@ref refs-benchmarking). The companion GRID DATA
program was created because openly available cases "do not properly
represent the challenging environments encountered by present and future
power grids", with the explicit goal of producing data realistic enough "to
convince industry that, yes, these algorithms work on real systems"
[[5]](@ref refs-benchmarking). This is a funder and a regulator ecosystem telling academia
that its evaluation practice, not its algorithmic creativity, is the
bottleneck — and the FERC staff papers on ACOPF make the industry stakes
concrete: decades after its formulation the ACOPF still is not solved to
industry requirements at scale, while even small dispatch-efficiency gains
would be worth billions [[7]](@ref refs-benchmarking).

Energy research more broadly has drawn the same conclusion about itself:
open data and open software are preconditions for reproducible,
higher-quality science, and the field has lagged others in adopting them
[[15]](@ref refs-benchmarking), with little formal guidance on how modeling studies should be
conducted and reported [[16]](@ref refs-benchmarking).

## What aligning would take

The transmission community's answer — converge on open benchmark libraries
(PGLib-OPF [[1]](@ref refs-benchmarking)), realistic synthetic cases validated against the
statistics of real grids [[10]](@ref refs-benchmarking), and competition-grade problem
specifications with full constraint fidelity [[6]](@ref refs-benchmarking) — worked. Solver
performance claims became comparable, and the GO Competition retrospective
documents how much engineering it took to make academic methods survive
contact with realistic, fully-constrained cases [[6]](@ref refs-benchmarking).

Distribution needs the same three ingredients, and each is harder:

1. **Expressive open datasets.** Real or realistic feeders that exercise the
   full construction vocabulary — four-wire, SWER, split-phase, delta,
   meshed — not just the subset that is convenient to model. The few that
   exist (ENWL's 128 real UK LV feeders [[12]](@ref refs-benchmarking), CIGRE's DER-integration
   benchmarks [[17]](@ref refs-benchmarking), SimBench [[18]](@ref refs-benchmarking), NREL's SMART-DS synthetic
   distribution systems [[19]](@ref refs-benchmarking)) each cover part of the space; none
   covers it with conductor-level, optimization-ready fidelity.

2. **Unambiguous problem specifications.** A case must carry its own context:
   which bounds are active, what the grounding and terminal conventions are,
   what the source model is, what was assumed when data was missing. If two
   groups can load the same file and silently solve different problems, the
   file is not a benchmark yet.

3. **Independent validation.** A published solution should be checkable
   without the author's code — against a simulator, against closed-form
   results, against constraint residuals recomputed from first principles.

This is the program the BMOPF data model and this package pursue: the
[specification](spec/index.md) makes bounds, grounding, and conventions
explicit and machine-checkable; [`analyze`](analysis.md) states every case's
modeling convention and hidden assumptions; [validation](validation.md)
cross-checks the reference OPF against OpenDSS, closed-form solutions, and
PowerModelsDistribution; and [provenance](methodology.md) records every
transformation applied during ingestion.

## A showcase: where the 80% assumptions break

The tutorials in this documentation double as a concrete exhibit. Each one
is a case where a common simplification — one that survives on standard test
feeders — produces a wrong or misleading answer on a network that industry
actually operates:

| If you assume… | …you get this wrong | Demonstrated in |
|---|---|---|
| Three wires suffice (Kron reduction) | Neutral voltage rise, unbalance costs, effective ratings | [Impedance models & OPF decisions](tutorial_impedance_models.md) |
| Sequence/balanced impedances | Which phase binds first, and whether asymmetry-aware dispatch helps | [Line geometry & impedances](tutorial_line_geometry.md), [Impedance models](tutorial_impedance_models.md) |
| SWER is too exotic to model | Whether rural feeders are feasible at all under new load | [SWER case study](tutorial_swer.md) |
| Transformers are ideal ratio changers | Loss allocation, tap feasibility, voltage regulation accuracy | [Transformer models](transformer_models.md), [Tap optimisation](tutorial_tap.md) |
| Unbalance is noise, not a control target | The value of D-STATCOM/IBR unbalance compensation | [D-STATCOM unbalance study](tutorial_statcom.md) |
| The solver's `LOCALLY_SOLVED` is the answer | Silent constraint violations and solution-quality issues | [Trust but verify](tutorial_trust_but_verify.md), [Bounds & feasibility](bounds/index.md) |
| Snapshot studies represent operation | Which hours actually bind, and what peak events cost | [Time series on an LV feeder](tutorial_timeseries.md) |

The point of the exhibit is not that these components are difficult — it is
that a benchmark suite *without* them cannot distinguish a method that
generalizes from one that merely fits the test set.

## [References](@id refs-benchmarking)

1. S. Babaeinejadsarookolaee et al. (IEEE PES Task Force on Benchmarks for
   Validation of Emerging Power System Algorithms), "The Power Grid Library
   for Benchmarking AC Optimal Power Flow Algorithms,"
   [arXiv:1908.02788](https://arxiv.org/abs/1908.02788), 2019/2021.
2. IEEE Distribution Planning Working Group (W. H. Kersting), "Radial
   Distribution Test Feeders," *IEEE Trans. Power Systems* 6(3):975–985,
   1991. [DOI:10.1109/59.119237](https://doi.org/10.1109/59.119237).
3. K. P. Schneider et al., "Analytic Considerations and Design Basis for the
   IEEE Distribution Test Feeders," *IEEE Trans. Power Systems*
   33(3):3181–3188, 2018.
   [DOI:10.1109/TPWRS.2017.2760011](https://doi.org/10.1109/TPWRS.2017.2760011).
4. F. E. Postigo Marcos et al., "A Review of Power Distribution Test Feeders
   in the United States and the Need for Synthetic Representative Networks,"
   *Energies* 10(11):1896, 2017.
   [DOI:10.3390/en10111896](https://doi.org/10.3390/en10111896).
5. ARPA-E, "GRID DATA: Generating Realistic Information for the Development
   of Distribution and Transmission Algorithms,"
   [program page](https://arpa-e.energy.gov/programs-and-initiatives/view-all-programs/grid-data),
   2016.
6. ARPA-E Grid Optimization Competition,
   ["About the Competition"](https://gocompetition.energy.gov/about-competition);
   I. Aravena et al., "Recent Developments in Security-Constrained AC Optimal
   Power Flow: Overview of Challenge 1 in the ARPA-E Grid Optimization
   Competition," *Operations Research*, 2023
   ([arXiv:2206.07843](https://arxiv.org/abs/2206.07843)).
7. M. B. Cain, R. P. O'Neill, A. Castillo, "History of Optimal Power Flow and
   Formulations," FERC Staff Technical Paper, 2012.
   [PDF](https://www.ferc.gov/sites/default/files/2020-05/acopf-1-history-formulation-testing.pdf).
8. "Optimizing Parameters of the LinDistFlow Power Flow Approximation for
   Distribution Systems," 2024/2025.
   [arXiv:2404.05125](https://arxiv.org/abs/2404.05125).
9. S. Claeys, F. Geth, G. Deconinck, "Optimal power flow in four-wire
   distribution networks: Formulation and benchmarking," *Electric Power
   Systems Research* 207:107797, 2022 (PSCC 2022).
   [arXiv:2204.08126](https://arxiv.org/abs/2204.08126).
10. A. B. Birchfield et al., "Grid Structural Characteristics as Validation
    Criteria for Synthetic Networks," *IEEE Trans. Power Systems*
    32(4):3258–3265, 2017.
    [DOI:10.1109/TPWRS.2016.2616385](https://doi.org/10.1109/TPWRS.2016.2616385).
11. A. J. Urquhart, "Accuracy of Low Voltage Electricity Distribution Network
    Modelling," PhD thesis, Loughborough University, 2016.
    [PDF](https://dspace.lboro.ac.uk/dspace-jspui/bitstream/2134/21799/2/Thesis-2016-Urquhart.pdf).
12. Electricity North West / University of Manchester, "Low Voltage Network
    Solutions" (Low Carbon Networks Fund project; 128 real UK LV feeders as
    OpenDSS models), 2011–2014.
    [Project page](https://www.enwl.co.uk/future-energy/innovation/smaller-projects/low-carbon-networks-fund/low-voltage-network-solutions/).
13. T. Joswig-Jones, K. Baker, A. S. Zamzam, "OPF-Learn: An Open-Source
    Framework for Creating Representative AC Optimal Power Flow Datasets,"
    IEEE ISGT 2022. [arXiv:2111.01228](https://arxiv.org/abs/2111.01228).
14. T. Wolgast, A. Nieße, "Learning the Optimal Power Flow: Environment
    Design Matters," *Energy and AI*, 2024.
    [arXiv:2403.17831](https://arxiv.org/abs/2403.17831).
15. S. Pfenninger, J. DeCarolis, L. Hirth, S. Quoilin, I. Staffell, "The
    importance of open data and software: Is energy research lagging
    behind?" *Energy Policy* 101:211–215, 2017.
    [DOI:10.1016/j.enpol.2016.11.046](https://doi.org/10.1016/j.enpol.2016.11.046).
16. J. DeCarolis et al., "Formalizing best practice for energy system
    optimization modelling," *Applied Energy* 194:184–198, 2017.
    [DOI:10.1016/j.apenergy.2017.03.001](https://doi.org/10.1016/j.apenergy.2017.03.001).
17. CIGRE Task Force C6.04.02, "Benchmark Systems for Network Integration of
    Renewable and Distributed Energy Resources," Technical Brochure 575,
    CIGRE, 2014.
18. S. Meinecke et al., "SimBench — A Benchmark Dataset of Electric Power
    Systems to Compare Innovative Solutions Based on Power Flow Analysis,"
    *Energies* 13(12):3290, 2020.
    [DOI:10.3390/en13123290](https://doi.org/10.3390/en13123290).
19. B. Palmintier et al., "SMART-DS: Synthetic Models for Advanced, Realistic
    Testing: Distribution Systems and Scenarios," NREL, 2017.
    [PDF](https://docs.nrel.gov/docs/fy17osti/68764.pdf).

Related reading in this documentation: D. K. Molzahn and I. A. Hiskens's
survey of power-flow relaxations and approximations
([open PDF](https://molzahn.github.io/pubs/molzahn_hiskens-fnt2019.pdf))
catalogues in depth where and why approximations of the power flow equations
lose accuracy, and is the standard starting point for choosing a formulation
consciously rather than by convention — the theme picked up in
[Impedance models & OPF decisions](tutorial_impedance_models.md).
