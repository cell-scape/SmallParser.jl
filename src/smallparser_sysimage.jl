Base.init_depot_path()
Base.init_load_path()

@eval Module() begin
    Base.include(@__MODULE__, "SmallParser.jl")
    for (pkgid, mod) in Base.loaded_modules
        if !(pkgid.name in ("Main", "Core", "Base"))
            eval(@__MODULE__, :(const $(Symbol(mod)) = $mod))
        end
    end
    for statement in readlines("sp_precompile.jl")
        try
            Base.include_string(@__MODULE__, statement)
        catch
            Core.println("failed to compile statement: ", statement)
        end
    end
end

empty!(LOAD_PATH)
empty!(DEPOT_PATH)
