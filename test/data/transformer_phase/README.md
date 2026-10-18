# Transformer phase reporting witness (#268)

Synthetic complete three-phase delta/wye transformer. Base `eb267ea24` reports
`Dyn0` for these letter labels, `Dyn1` after a/b/c→1/2/3, and omits neutral
accessibility when n→N0. No physical rewiring occurs under these relabelings.

An independent prescribed-source primitive calculation gives a 30° target lag
for the authored backward delta orientation: `Va - Vc` has angle −30°. Tests
cover every phase-map permutation and source rotations, then independently solve
the passive primitive block at zero secondary current. The fixture is package
behavior evidence linked to PSK-000006, not a new scientific claim.
