#define TARGET_X 2
#define TARGET_Z 8
#define TARGET_TYPE 'o'
#define TARGET_HEIGHT 4
#define SURE_LEAVES 12

int nextInt(ulong* seed, uchar bound);

kernel void trees(global ulong *starts, global ulong *ends, global ulong *results) {
	int id = get_global_id(0);

    ulong treeSeedStart = starts[id];
    ulong treeSeedEnd = ends[id];
    ulong seedsFound = 0;

    #pragma unroll
    for (ulong treeSeed = treeSeedStart; treeSeed < treeSeedEnd; treeSeed++) {
		ulong baseSeed = treeSeed | ((ulong) TARGET_X << 44);

        if ((((baseSeed *     25214903917LU +              11LU) >> 44) & 15) !=  8) continue;
        if ((((baseSeed * 205749139540585LU +    277363943098LU) >> 17) %  5) ==  0) continue;
        if ((((baseSeed * 233752471717045LU +  11718085204285LU) >> 17) % 10) ==  0) continue;
        if ((((baseSeed *  55986898099985LU +  49720483695876LU) >> 17) %  3) !=  0) continue;
        if ((((baseSeed * 120950523281469LU + 102626409374399LU) >> 47) &  1) !=  0) continue;
        if ((((baseSeed *  76790647859193LU +  25707281917278LU) >> 47) &  1) !=  0) continue;
        if ((((baseSeed *  61282721086213LU +  25979478236433LU) >> 47) &  1) !=  1) continue;
        if ((((baseSeed * 128954768138017LU + 137139456763464LU) >> 47) &  1) !=  1) continue;
        if ((((baseSeed * 177269950146317LU + 148267022728371LU) >> 47) &  1) !=  1) continue;
        if ((((baseSeed *  19927021227657LU + 127911637363266LU) >> 47) &  1) !=  0) continue;
        if ((((baseSeed *  92070806603349LU +  65633894156837LU) >> 47) &  1) !=  0) continue;
        if ((((baseSeed *  28158748839985LU + 233987836661708LU) >> 47) &  1) !=  1) continue;
        if ((((baseSeed * 118637304785629LU + 262259097190887LU) >> 47) &  1) !=  0) continue;
        if ((((baseSeed * 127636996050457LU + 159894566279526LU) >> 47) &  1) !=  0) continue;
        if ((((baseSeed *  12659659028133LU + 156526639281273LU) >> 47) &  1) !=  0) continue;
        if ((((baseSeed * 120681609298497LU +  14307911880080LU) >> 47) &  1) !=  1) continue;
        
//        printf("%lld\n", baseSeed);
        results[id + seedsFound] = treeSeed;
//        results[id + seedsFound] = baseSeed;
        seedsFound += 1;
    }
}
