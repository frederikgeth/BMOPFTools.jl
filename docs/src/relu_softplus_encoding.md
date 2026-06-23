# Tech note: smooth droop encoding

The Volt-var (VVC) and Volt-watt (VWC) characteristics of AS/NZS 4777.2 / IEEE
1547 are **piecewise-linear (PWL)** functions of voltage magnitude. PWL functions
are not differentiable at their breakpoints, and primal–dual interior-point
solvers such as Ipopt inherit Newton's requirement that the constraint functions
be **twice continuously differentiable**: a kink makes the Jacobian jump and the
Hessian a Dirac spike, which degrades the line search near a breakpoint. This
note documents how BMOPFTools encodes the droop so that the OPF stays smooth,
exact to a controllable tolerance, and numerically robust — and writes out the
derivatives and the stable evaluation that the source only summarises.

The approach follows Mhanna, Geth, Quiertant & Mancarella [1], §II-C.1; the
smoothing is the Chen–Harker–Kanzow–Smale (CHKS) softplus [2]. Numbered citations
refer to the [references](@ref relu-refs) below. The implementation lives in
[`control_curves.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/ext/BMOPFOpfExt/control_curves.jl).

## 1. The ReLU-sum encoding

Any continuous PWL function $f$ defined by non-decreasing breakpoints
$(\bar x_1,\bar y_1),\dots,(\bar x_n,\bar y_n)$ and clamped flat outside
$[\bar x_1,\bar x_n]$ can be written as a single baseline plus a sum of
shifted/scaled **rectified linear units** $\operatorname{ReLU}(z)=\max(0,z)$:

```math
f(U) \;=\; \bar y_1 \;+\; \sum_{i} a_i \,\operatorname{ReLU}(U-\bar x_i).
```

Each interior segment $i$ (between $\bar x_i$ and $\bar x_{i+1}$) with slope
$s_i$ contributes **two** terms — $(+s_i,\bar x_i)$ turns the slope on at the
segment start and $(-s_i,\bar x_{i+1})$ turns it off at the end — so the slopes
*telescope*: the running slope below $\bar x_1$ is $0$, equals $s_i$ on segment
$i$, and returns to $0$ above $\bar x_n$. This is the "two-triple per segment"
form produced by `breakpoints_to_triples`.

For the canonical Volt-watt curve (100 % below 253 V dropping to 20 % at 260 V)
the encoding is the two triples $(-\tfrac{0.8}{7},253)$ and $(+\tfrac{0.8}{7},260)$
on a baseline of $1.0$. Zero-slope (deadband) segments contribute no triples.

The encoding is exact for the kinked curve and is used as the reference
(`curve_value_exact`) against which the smooth surrogate is tested.

## 2. The softplus surrogate

The non-smoothness is confined to the ReLU kink at $z=0$. Replace each ReLU by
its **softplus** surrogate with smoothing parameter $\varepsilon>0$,

```math
\operatorname{ReLU}^{\varepsilon}(z) \;=\; \varepsilon\,\log\!\bigl(1+e^{z/\varepsilon}\bigr),
```

giving the smooth droop

```math
f^{\varepsilon}(U) \;=\; \bar y_1 \;+\; \sum_i a_i\,\varepsilon\,\log\!\bigl(1+e^{(U-\bar x_i)/\varepsilon}\bigr).
```

This function $f^{\varepsilon}$ is infinitely differentiable, $C^\infty$, and its slopes match the original droop exactly
in the limit. Two properties make it a principled choice:

- **Monotone, bounded error.** The softplus brackets the ReLU from above with a
  uniform bound [1, 2]:
  ```math
  0 \;\le\; \operatorname{ReLU}^{\varepsilon}(z) - \operatorname{ReLU}(z) \;\le\; \varepsilon\log 2 .
  ```
  The worst-case error is $\varepsilon\log 2$, attained at the kink, and it
  shrinks **linearly** in $\varepsilon$. Summing over triples, the curve error is
  bounded by $\bigl(\sum_i |a_i|\bigr)\varepsilon\log 2$.
- **Exact limit.** $\operatorname{ReLU}^{\varepsilon}(z)\to\operatorname{ReLU}(z)$
  pointwise as $\varepsilon\to 0^+$, so the smoothing is a controllable
  approximation.

## 3. Closed-form first and second derivatives

Because the operator is a single-argument function, BMOPFTools registers it with
JuMP's `add_nonlinear_operator` together with **explicit** first and second
derivatives, avoiding automatic-differentiation overhead and giving Ipopt an
exact Hessian. With $z=U-\bar x$ and the logistic (sigmoid)
$\sigma(t)=\tfrac{1}{1+e^{-t}}$,

```math
\frac{d}{dU}\operatorname{ReLU}^{\varepsilon}(z) = \sigma\!\Bigl(\tfrac{z}{\varepsilon}\Bigr),
\qquad
\frac{d^2}{dU^2}\operatorname{ReLU}^{\varepsilon}(z) = \frac{1}{\varepsilon}\,\sigma\!\Bigl(\tfrac{z}{\varepsilon}\Bigr)\Bigl(1-\sigma\!\Bigl(\tfrac{z}{\varepsilon}\Bigr)\Bigr).
```

The first derivative is a smooth switch rising from $0$ to $1$ across a band of
width $\mathcal O(\varepsilon)$ around the breakpoint; the second derivative is a
bump of height $\mathcal O(1/\varepsilon)$ and width $\mathcal O(\varepsilon)$ —
a smooth, integrable stand-in for the Dirac curvature of the exact kink. For the
full curve the derivatives are the corresponding $a_i$-weighted sums:

```math
f^{\varepsilon\prime}(U) = \sum_i a_i\,\sigma\!\Bigl(\tfrac{U-\bar x_i}{\varepsilon}\Bigr),
\qquad
f^{\varepsilon\prime\prime}(U) = \frac{1}{\varepsilon}\sum_i a_i\,\sigma_i(1-\sigma_i),\quad \sigma_i=\sigma\!\Bigl(\tfrac{U-\bar x_i}{\varepsilon}\Bigr).
```

These are exactly the `f`, `df`, `d2f` closures passed to the operator in
`relu_operator`.

## 4. Numerically stable evaluation (StatsFuns)

A literal evaluation of $\log(1+e^{t})$ and $\tfrac{1}{1+e^{-t}}$ with $t=z/\varepsilon$
overflows or underflows well inside the operating range — and the problem gets
*worse* as $\varepsilon\to 0$, because $t=z/\varepsilon$ grows like $1/\varepsilon$:

- for large positive $t$, $e^{t}$ overflows to `Inf`, so $\log(1+e^t)$ returns
  `Inf` instead of $\approx t$;
- for large negative $t$, $e^{-t}$ overflows in the logistic denominator, and
  $1+e^{t}\to 1$ loses all the information in $e^t$.

BMOPFTools therefore evaluates the surrogate through
[StatsFuns.jl](https://github.com/JuliaStats/StatsFuns.jl)'s `log1pexp` and
`logistic`, which use the regime-split identities of Mächler [3]:

```math
\log(1+e^{t}) =
\begin{cases}
e^{t} & t \lesssim -37 \quad(\text{1+}e^t\approx 1;\ \log 1p)\\
\log\!\bigl(1+e^{t}\bigr) & -37 \lesssim t \lesssim 18\\
t + e^{-t} & 18 \lesssim t \lesssim 33.3\\
t & t \gtrsim 33.3
\end{cases}
```

so the result is accurate to full Float64 precision and never overflows: the
large-$t$ branch returns $t$ (the ReLU asymptote) directly, and the small-$t$
branch uses `log1p` to retain precision near zero. `logistic` applies the
companion overflow-safe split, evaluating $\tfrac{e^{t}}{1+e^{t}}$ for $t<0$ and
$\tfrac{1}{1+e^{-t}}$ for $t\ge 0$ so the exponential argument is always
non-positive. The second derivative reuses $\sigma$, so it inherits the same
stability. This is what lets the encoding use aggressively small $\varepsilon$
without the floating-point failures the naive formulas would suffer [1, §III-C].

## 5. Choosing the smoothing $\varepsilon$

The smoothing is **relative to the voltage scale**. `breakpoints_to_triples`
works in model units (per-unit when the OPF is solved per-unit), and the operator
uses

```math
\varepsilon = \texttt{relu\_eps}\times\overline{x},\qquad \overline{x}=\tfrac1n\sum_i \bar x_i,
```

i.e. `relu_eps` (default `2e-3`, exposed as the `volt_var_watt_eps` keyword of
[`solve_opf`](@ref)) times the mean breakpoint. Scaling $\varepsilon$ to the mean
breakpoint keeps the corner radius a fixed *fraction* of the voltage range, so the
droop is identical in SI and per-unit solves.

The tradeoff is the usual one:

- **smaller $\varepsilon$** ⇒ tighter match to the standard's curve (error
  $\propto\varepsilon$), but a sharper second-derivative bump
  ($\propto 1/\varepsilon$) that can slow or trip the line search if a solution
  sits exactly on a breakpoint;
- **larger $\varepsilon$** ⇒ rounder corners and easier conditioning, at the cost
  of a visibly smoothed deadband.

Mhanna et al. [1, §IV-C] benchmark this sweep and recommend a softplus smoothing
small enough to stay well inside the $\pm 7.5\,\%$ voltage-accuracy band of real
inverters while preserving reliability; in their normalisation $\varepsilon\le
10^{-5}$ was the sweet spot. The default here is deliberately conservative and can
be tightened per study. The same paper presents a **quadratic Bézier spline** as
an alternative smoothing with an equivalent $\Delta U$ tolerance; BMOPFTools ships
the softplus form, which has the cheaper gradient/Hessian evaluation.

## 6. Provenance and related work

The encoding above is the composition of two well-established ideas; naming them
clarifies what is standard and what is specific to this implementation.

**Representing a PWL function as a sum of hinges.** Writing a continuous PWL
function as a baseline plus shifted $\max(0,\cdot)$ terms (§1) is the degree-1
*truncated power basis* of spline theory. It is the building block of Friedman's
multivariate adaptive regression splines (MARS) [7] and of Breiman's hinging
hyperplanes, and the canonical-PWL representation theory of Chua & Kang [8] shows
that every continuous PWL function is a linear combination of maxima of affine
functions — the single-variable case being exactly the hinge sum used here.
Equivalently, a one-dimensional ReLU sum *is* a shallow ReLU network, which is
why the encoding reads like one.

**Smoothing the hinge with a softplus.** Replacing $\max(0,z)$ by
$\varepsilon\log(1+e^{z/\varepsilon})$ (§2) is the smoothing-of-the-plus-function
idea of Chen & Mangasarian [9], who obtain the softplus by integrating a sigmoid
precisely to convert nonsmooth inequality/complementarity problems into smooth
ones solvable by Newton — the same motivation as here. The error bound and the
broader smoothing family are the Chen–Harker–Kanzow–Smale (CHKS) line [2]. A
unifying view: $\operatorname{softplus}(x)=\varepsilon\,\operatorname{logsumexp}(0,x/\varepsilon)$,
and log-sum-exp is the canonical entropic (Nesterov) smoothing of $\max$ [10], so
the surrogate is the simplest smooth-max. More recently, the pattern "relax to a
program, then smooth it" has been systematised under differentiable
programming [11], where softplus is a running example.

**What is specific here.** Neither ingredient is novel in isolation; the
contribution is their *exact-slope* composition for standardised droop — the
baseline and triples are placed analytically so the surrogate reproduces the
AS/NZS 4777.2 / IEEE 1547 slopes in the $\varepsilon\to 0$ limit — together with
the numerically stable `log1pexp`/`logistic` evaluation (§4) and deployment inside
a neutral-explicit four-wire OPF [1]. The same smooth-droop strategy is applied to
AC–DC converter droop with saturation in a companion paper [12].

## [References](@id relu-refs)

1. S. Mhanna, F. Geth, L. Quiertant, P. Mancarella, "Volt-VAr-Watt Optimization
   in Four-Wire Low-Voltage Networks: Exact Nonlinear Models and Smooth
   Approximations," *IEEE Trans. Power Systems*, 2026,
   doi:10.1109/TPWRS.2026.3677246.
2. B. Chen, P. T. Harker, "Smooth approximations to nonlinear complementarity
   problems," *SIAM J. Optim.* 7 (2) (1997) 403–420.
3. M. Mächler, "Accurately computing $\log(1-e^{-|a|})$ — assessed by the
   `Rmpfr` package," 2012 (the `log1pexp`/`logistic` regime split used by
   [StatsFuns.jl](https://github.com/JuliaStats/StatsFuns.jl)).
4. J. Huchette, J. P. Vielma, "Nonconvex piecewise linear functions: Advanced
   formulations and simple modeling tools," *Operations Research* 71 (5) (2023)
   1835–1856 (the exact binary/logarithmic PWL alternative).
5. A. Wächter, L. T. Biegler, "On the implementation of an interior-point filter
   line-search algorithm for large-scale nonlinear programming," *Math.
   Program.* 106 (1) (2006) 25–57 (Ipopt; the $C^2$ requirement).
6. M. Lubin, O. Dowson, J. Dias Garcia, J. Huchette, B. Legat, J. P. Vielma,
   "JuMP 1.0: Recent improvements to a modeling language for mathematical
   optimization," *Math. Program. Comput.*, 2023 (user-defined nonlinear
   operators).
7. J. H. Friedman, "Multivariate adaptive regression splines," *Ann. Statist.*
   19 (1) (1991) 1–67 (hinge-function / truncated-power basis).
8. L. O. Chua, S. M. Kang, "Section-wise piecewise-linear functions: Canonical
   representation, properties, and applications," *Proc. IEEE* 65 (6) (1977)
   915–929 (canonical PWL representation).
9. C. Chen, O. L. Mangasarian, "A class of smoothing functions for nonlinear and
   mixed complementarity problems," *Comput. Optim. Appl.* 5 (2) (1996) 97–138
   (softplus as the integral of a sigmoid, smoothing the plus function).
10. Yu. Nesterov, "Smooth minimization of non-smooth functions," *Math. Program.*
    103 (1) (2005) 127–152 (entropic smoothing of $\max$ via log-sum-exp).
11. M. Blondel, V. Roulet, "The Elements of Differentiable Programming,"
    arXiv:2403.14606, 2024 (smoothing programs; softplus as a running example).
12. G. Mohy-ud-din, R. Heidari, F. Geth, H. Ergun, S. M. M. Uddin, "AC-DC Power
    Systems Optimization with Droop Control Smooth Approximation,"
    arXiv:2409.18376, 2024 (companion smooth-droop application).
