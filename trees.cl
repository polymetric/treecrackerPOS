#define TARGET_X 2

kernel void trees(global ulong *starts, global ulong *ends, global ulong *results, global size_t *results_count) {
	int id = get_global_id(0);

    ulong treeSeedStart = starts[id];
    ulong treeSeedEnd = ends[id];
    ulong seedsFound = 0;

    for (ulong treeSeed = treeSeedStart; treeSeed < treeSeedEnd; treeSeed++) {
		ulong baseSeed = treeSeed | ((ulong) TARGET_X << 44);

        if ((((baseSeed *     25214903917LU +              11LU) >> 44) & 15) != 15) continue;
        if ((((baseSeed *  55986898099985LU +  49720483695876LU) >> 47) &  1) !=  0) continue;
        if ((((baseSeed *  76790647859193LU +  25707281917278LU) >> 47) &  1) !=  1) continue;
        if ((((baseSeed * 128954768138017LU + 137139456763464LU) >> 47) &  1) !=  1) continue;
        if ((((baseSeed *  19927021227657LU + 127911637363266LU) >> 47) &  1) !=  0) continue;
        if ((((baseSeed *  28158748839985LU + 233987836661708LU) >> 47) &  1) !=  0) continue;
        if ((((baseSeed * 127636996050457LU + 159894566279526LU) >> 47) &  1) !=  0) continue;
        if ((((baseSeed * 205749139540585LU +    277363943098LU) >> 17) %  5) !=  0) continue;
        if ((((baseSeed * 233752471717045LU +  11718085204285LU) >> 17) %  3) !=  1) continue;
        
        results[id + seedsFound] = baseSeed;
        seedsFound += 1;
    }

    results_count[id] = seedsFound;
}
