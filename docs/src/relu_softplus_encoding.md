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

$f^{\varepsilon}$ is $C^\infty$, and its slopes match the original droop exactly
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
  relaxation, not a model change.

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
the softplus form, which has the cheaper gradient/Hessian evaluation [1, Fig. 4].

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
   formulations and simple modeling tools," *Operations Research* 71 (5) (2019)
   1835–1856 (the exact binary/logarithmic PWL alternative).
5. A. Wächter, L. T. Biegler, "On the implementation of an interior-point filter
   line-search algorithm for large-scale nonlinear programming," *Math.
   Program.* 106 (1) (2006) 25–57 (Ipopt; the $C^2$ requirement).
6. M. Lubin, O. Dowson, J. Dias Garcia, J. Huchette, B. Legat, J. P. Vielma,
   "JuMP 1.0: Recent improvements to a modeling language for mathematical
   optimization," *Math. Program. Comput.*, 2023 (user-defined nonlinear
   operators).
