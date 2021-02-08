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

    char treeTypes[TREE_COUNT] = {
            'o',
            'o',
            'o',
            'b',
            'o',
            'b',
            'o',
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

    int sureLeaves[TREE_COUNT] = {
            9,
            12,
            12,
            11,
            5,
            6,
            8,
    };

    char gennedLeaves[12];

    long treeSeedStart = starts[id];
    long treeSeedEnd = ends[id];

    for (long treeSeed = treeSeedStart; treeSeed < treeSeedEnd; treeSeed++) {
		long seed = treeSeed;
        int baseX = nextInt(&seed, 16);
        int baseZ = nextInt(&seed, 16);
        char type = 'o';
        if (nextInt(&seed, 5) == 0) {
            type = 'b';
        } else if (nextInt(&seed, 10) == 0) {
            type = 'B';
        }
		if (type != 'B') {
        	int trunkHeight = nextInt(&seed, 3) + 4;
        	for (int leaf = 0; leaf < 12; leaf++) {
        	    gennedLeaves[leaf] = nextInt(&seed, 2) != 0 ? 'l' : 'n';
        	}
        	for (int targetTree = 0; targetTree < TREE_COUNT; targetTree++) {
        	    if (baseX == trees[targetTree][0]
        	            && baseZ == trees[targetTree][1]
        	            && trunkHeight == treeHeights[targetTree]
						&& type == treeTypes[targetTree]
        	    ) {
        	        int leafMatches = 0;
        	        for (int leaf = 0; leaf < 12; leaf++) {
        	            if (treeLeaves[targetTree][leaf] == gennedLeaves[leaf]) {
        	                leafMatches++;
        	            }
        	        }
        	        if (leafMatches == sureLeaves[targetTree]) {
        	            printf("%lld %lld\n", targetTree, treeSeed);
        	        }
        	    }
        	}
		} else {
			
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

