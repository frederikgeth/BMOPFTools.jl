# Run outside the package/test environments: no checked-in or local Manifest is used.
using Pkg

root = normpath(joinpath(@__DIR__, ".."))
jump_version = isempty(ARGS) ? "latest" : only(ARGS)
mktempdir() do env
    Pkg.activate(env)
    Pkg.develop(PackageSpec(path=root))
    Pkg.instantiate()
    Pkg.precompile(; strict=true)
    function smoke(mode)
        cmd = `$(Base.julia_cmd()) --startup-file=no --project=$env $(joinpath(@__DIR__, "installation_smoke.jl")) $mode`
        process = run(ignorestatus(addenv(cmd, "JULIA_LOAD_PATH" => "@:@stdlib")))
        success(process) || error("Installation smoke failed: $mode")
    end
    smoke("core")
    spec = jump_version == "latest" ? PackageSpec(name="JuMP") :
        PackageSpec(name="JuMP", version=VersionNumber(jump_version))
    Pkg.add(spec)
    if jump_version != "latest"
        Pkg.pin(spec)
    end
    Pkg.precompile(; strict=true)
    smoke("jump_first")
    smoke("package_first")
    Pkg.add("Ipopt")
    Pkg.precompile(; strict=true)
    smoke("solver")
    Pkg.status()
end
