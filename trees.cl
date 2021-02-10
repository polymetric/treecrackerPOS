#define TARGET_X 2

kernel void trees(global ulong *starts, global ulong *ends, global ulong *results, global size_t *results_count) {
	int id = get_global_id(0);

    ulong treeSeedStart = starts[id];
    ulong treeSeedEnd = ends[id];
    ulong seedsFound = 0;

    #pragma unroll
    for (ulong treeSeed = treeSeedStart; treeSeed < treeSeedEnd; treeSeed++) {
		ulong baseSeed = treeSeed | ((ulong) TARGET_X << 44);

        if ((((baseSeed *     25214903917LU +              11LU) >> 44) & 15) != 11) continue;
        if ((((baseSeed * 205749139540585LU +    277363943098LU) >> 17) %  5) ==  0) continue;
        if ((((baseSeed * 233752471717045LU +  11718085204285LU) >> 17) % 10) ==  0) continue;
        if ((((baseSeed *  55986898099985LU +  49720483695876LU) >> 17) %  3) !=  0) continue;
        if ((((baseSeed * 120950523281469LU + 102626409374399LU) >> 47) &  1) !=  1) continue;
        if ((((baseSeed * 128954768138017LU + 137139456763464LU) >> 47) &  1) !=  0) continue;
        if ((((baseSeed * 177269950146317LU + 148267022728371LU) >> 47) &  1) !=  0) continue;
        if ((((baseSeed *  28158748839985LU + 233987836661708LU) >> 47) &  1) !=  1) continue;
        if ((((baseSeed * 118637304785629LU + 262259097190887LU) >> 47) &  1) !=  0) continue;
        if ((((baseSeed *  12659659028133LU + 156526639281273LU) >> 47) &  1) !=  1) continue;
        if ((((baseSeed * 120681609298497LU +  14307911880080LU) >> 47) &  1) !=  1) continue;
        
        results[id + seedsFound] = baseSeed;
        seedsFound += 1;
    }

    results_count[id] = seedsFound;
}
