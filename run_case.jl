using Santiago

function main(args)
    techs = open("./test/example_techs.json", "r") do f
        JSON3.read(f)
    end

    case = open(args[1], "r") do f
        JSON3.read(f)
    end

    result = appropriateness(techs, case)

    println(result)
    println(JSON3.write(result))
end

main(ARGS)