#! /usr/bin/julia

#= 
Small Parser for Project Timelogs
Brad Dowling
CIS 620, Fall 2020
=#

module SmallParser

export parse_timelog, summary_stastistics

using DataFrames, Dates, StatsBase

# Utility Functions

"Split log file into lines"
function process_file(filename::String)
    f = open(filename)
    lines = readlines(f)

    # Handle files with many null characters.
    if '\0' ∈ lines[1]
        lines = process_broken_file(lines)
    end

    lines = filter(x->length(x) > 0, lines)
    return split.(lines)
end


"Fix the files with many null chars"
function process_broken_file(lines)
    fixed_lines = join.(split.(lines, "\0"), "")
    fixed_lines = map(x->x[1:end-1], fixed_lines)
    
    return fixed_lines
end

"Process the data in the line vectors"
function process_lines(lines)
    dates = []
    start_times = []
    end_times = []
    activity = []

    last_date = ""
    last_activity = ""
    last_start = ""
    last_end = ""

    for line in lines
        if occursin(r"\d+/\d+/\d\d", line[1])
            if length(line) > 4
                last_activity = join(line[5:end], " ")
            end
            
            push!(dates, line[1][1:end-1])
            last_date = line[1][1:end-1]
            
            push!(start_times, line[2])
            last_start = line[2]

            # Handle comma separated timestamps
            if endswith(",", line[4])
                # cut it off and forget about second time stamp set
                line[4] = line[4][:end-1]

                # line components 5, 7 separated onto new line with
                # all other components identical
            end
            push!(end_times, line[4])
            last_end = line[4]
            
            push!(activity, last_activity)
        elseif occursin(r"\d+:\d\d", line[1])
            if length(line) > 3
                last_activity = join(line[4:end], " ")
            end
            
            push!(dates, last_date)
            
            push!(start_times, line[1])
            last_start = line[1]

            # Handle comma separated timestamps
            if endswith(",", line[3])
                # cut off second time
                line[3] = line[3][:end-1]

                # line components 4, 6 to be separated onto another line
                # with all other components identical.
            end
            
            push!(end_times, line[3])
            last_end = line[3]
            
            push!(activity, last_activity)
            
        elseif line[1] == "-"
            push!(dates, last_date)
            push!(start_times, last_start)
            push!(end_times, last_end)
            push!(activity, join(line, " "))
        end
    end
    
    # Make sure all columns are the same length
    @assert all(i->length(i) == length(dates),
                (dates, start_times, end_times, activity))

    return (dates, start_times, end_times, activity)
end

"Parse and normalize datetimes"
function fix_datetimes(dates, start_times, end_times)
    # Fix datetime types
    dates = Year(2000) .+ Date.(dates, dateformat"m/dd/yy")

    # Normalize hours
    for (i, t) in enumerate(start_times)
        if ~endswith(t, r"[ap]m")
            start_times[i] = join(cat(split(t, r"[ap]m")[1], "pm", dims=1), "")
        end
        if ~startswith(t, r"\d\d:\d\d")
            start_times[i] = join(cat("0", t, dims=1), "")
        end
        if endswith(t, r",")
            start_times[i] = t[1:end-1]
        end
    end
    for (i, t) in enumerate(end_times)
        if ~endswith(t, r"[ap]m")
            end_times[i] = join(cat(split(t, "[ap]m")[1], "pm", dims=1), "")
        end
        if ~startswith(t, r"\d\d:\d\d")
            end_times[i] = join(cat("0", t, dims=1), "")
        end
        if endswith(t, r",")
            end_times[i] = t[1:end-1]
        end
    end

    start_times = [Time(t, dateformat"II:MMpp") for t in start_times]
    end_times = [Time(t, dateformat"II:MMpp") for t in end_times]

    total = Minute.(end_times .- start_times)
    for (i, t) in enumerate(total)
        if t < Minute(0)
            total[i] = t + Minute(1440)
        end
    end

    return (dates, start_times, end_times, total)
end

"Create a dataframe from the parsed logfile"
function create_dataframe(dates, start_times, end_times, total, activity)
    return DataFrame(:Date => dates,
                     :Start => start_times,
                     :End => end_times,
                     :Total => total,
                     :Activity => activity)
end

### Public API

"Main function for parsing log files"
function parse_timelog(filename::String)::DataFrame
    lines = process_file(filename)
    (dates, start_times, end_times, activity) = process_lines(lines)
    (dates, start_times, end_times, total) = fix_datetimes(dates, start_times, end_times)
    return create_dataframe(dates, start_times, end_times, total, activity)
end

"Print Summary Statistics on Total time"
function summary_statistics(df::DataFrame)
    println("Total Time Spent: $(sum(df[!, :Total]))")
    println("Summary of time spent per session (minutes):")
    describe(Dates.value.(df[!, :Total]))
end


# Program entry point
Base.@ccallable function julia_main()::Cint
    try
        real_main()
    catch
        Base.invokelatest(Base.display_error, Base.catch_stack())
        return 1
    end
    return 0
end

function real_main()
    if length(ARGS) ≠ 1
        println("Usage: sh>  SmallParser.jl <logfile>")
        return
    end
    
    summary_statistics(parse_timelog(ARGS[1]))
end

if abspath(PROGRAM_FILE) == @__FILE__
    real_main()
end



end # module
