#define TREE_COUNT 7
#define TREE_GEN_AMT 11

int nextInt(long* seed, short bound);

kernel void trees(global long *starts, global long *ends, global long *results) {
    int id = get_global_id(0);

    int trees[TREE_COUNT][2] = {
            {   1,   1 },
            {   2,   8 },
            {  15,  10 },
            {  12,   2 },
            {   7,   3 },
            {   3,   4 },
            {   0,  12 },
    };

    int treeHeights[TREE_COUNT] = {
            5,
            4,
            5,
            5,
            6,
            6,
            4,
    };

    char treeLeaves[TREE_COUNT][12] = {
            { 'l', 'n', 'n', 'u', 'n', 'l', 'l', 'u', 'l', 'l', 'n', 'u', },
            { 'n', 'n', 'l', 'l', 'l', 'n', 'n', 'l', 'n', 'n', 'n', 'l', },
            { 'n', 'l', 'l', 'l', 'n', 'n', 'l', 'l', 'l', 'n', 'n', 'l', },
            { 'l', 'n', 'l', 'n', 'u', 'l', 'n', 'n', 'l', 'n', 'n', 'l', },
            { 'l', 'l', 'u', 'u', 'l', 'l', 'u', 'u', 'l', 'u', 'u', 'u', },
            { 'u', 'l', 'u', 'l', 'u', 'n', 'u', 'n', 'l', 'l', 'u', 'u', },
            { 'u', 'n', 'u', 'l', 'u', 'n', 'u', 'n', 'l', 'n', 'n', 'l', },
    };

	char gennedLeaves[12];

	long treeRegionSeedStart = starts[id];
    long treeRegionSeedEnd = ends[id];

    for (long treeRegionSeed = treeRegionSeedStart; treeRegionSeed < treeRegionSeedEnd; treeRegionSeed++) {
        long seed = treeRegionSeed;
        int matches = 0;
        for (int gennedTree = 0; gennedTree < TREE_GEN_AMT; gennedTree++) {
            int baseX = nextInt(&seed, 16);
            int baseZ = nextInt(&seed, 16);
            int trunkHeight = nextInt(&seed, 3) + 4;
            for (int leaf = 0; leaf < 12; leaf++) {
                gennedLeaves[leaf] = nextInt(&seed, 2) != 0 ? 'l' : 'n';
            }
            for (int leaf = 0; leaf < 4; leaf++) {
                nextInt(&seed, 2);
            }
            for (int targetTree = 0; targetTree < TREE_COUNT; targetTree++) {
                if (baseX == trees[targetTree][0]
                        && baseZ == trees[targetTree][1]
                        && trunkHeight == treeHeights[targetTree]
                ) {
                    int leafMatches = 0;
                    for (int leaf = 0; leaf < 12; leaf++) {
                        if (treeLeaves[targetTree][leaf] == gennedLeaves[leaf]) {
                            leafMatches++;
                        }
                    }
                    if (leafMatches == 12) {
                        matches++;
                    }
                }
            }
        }
        if (matches >= 2) {
            printf("found matches: %lld seed: %lld\n", matches, treeRegionSeed);
        }
        // prints seed every time the progress increases by 1/10000 of the seedspace
        if (treeRegionSeed % 281474976L == 0) {
            printf("current seed: %lld\n", treeRegionSeed);
        }
    }
}

int nextInt(long* seed, short bound) {
	int bits, value;
	do {
		*seed = (*seed * 0x5DEECE66DL + 0xBL) & ((1L << 48) - 1);
		bits = *seed >> 17;
		value = bits % bound;
	} while(bits - value + (bound - 1) < 0);
	return value;
}

