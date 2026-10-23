# Reactive capability witness (#89)

Original synthetic one-bus fixture, created for this regression; no external
network data. Values use SI units and positive IBR injection. At the prescribed
230 V source, PF = +0.8 imposes Q = -0.75 P. With Q >= -300 var and P <= 1200 W,
maximizing P has the unique power optimum P = 400 W, Q = -300 var. The injected
coil current is conjugate((400 - 300j)/230) A. The source balances its negative.

Before the reactive-box correction, the engine maximizes P to 1200 W and Q to
-900 var because the PF branch skips the declared Q box. This is a model-domain
witness, independent of network losses, parser behavior or external converters.
The tests also derive topology/control variants from this fixture explicitly.
