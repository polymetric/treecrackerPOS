#define TARGET_X 2
#define TARGET_Z 8
#define TARGET_TYPE 'o'
#define TARGET_HEIGHT 4
#define SURE_LEAVES 12

int nextInt(long* seed, short bound);

kernel void trees(global long *starts, global long *ends, global long *results) {
	int id = get_global_id(0);

//    int trees[TREE_COUNT][2] = {
//            {   1,   1 },
//            {   2,   8 },
//            {  15,  10 },
//            {  12,   2 },
//            {   7,   3 },
//            {   3,   4 },
//            {   0,  12 },
//    };
//
//    char treeTypes[TREE_COUNT] = {
//            'o',
//            'o',
//            'o',
//            'b',
//            'o',
//            'b',
//            'o',
//    };
//
//    int treeHeights[TREE_COUNT] = {
//            5,
//            4,
//            5,
//            5,
//            6,
//            6,
//            4,
//    };

    char treeLeaves[12] = {
//             'l', 'n', 'n', 'u', 'n', 'l', 'l', 'u', 'l', 'l', 'n', 'u',
             'n', 'n', 'l', 'l', 'l', 'n', 'n', 'l', 'n', 'n', 'n', 'l',
//             'n', 'l', 'l', 'l', 'n', 'n', 'l', 'l', 'l', 'n', 'n', 'l',
//             'l', 'n', 'l', 'n', 'u', 'l', 'n', 'n', 'l', 'n', 'n', 'l',
//             'l', 'l', 'u', 'u', 'l', 'l', 'u', 'u', 'l', 'u', 'u', 'u',
//             'u', 'l', 'u', 'l', 'u', 'n', 'u', 'n', 'l', 'l', 'u', 'u',
//             'u', 'n', 'u', 'l', 'u', 'n', 'u', 'n', 'l', 'n', 'n', 'l',
	};

//    int sureLeaves[TREE_COUNT] = {
//            9,
//            12,
//            12,
//            11,
//            5,
//            6,
//            8,
//    };

    long treeSeedStart = starts[id];
    long treeSeedEnd = ends[id];

    #pragma unroll
    for (long treeSeed = treeSeedStart; treeSeed < treeSeedEnd; treeSeed++) {
		long seed = treeSeed;
        uchar baseX = nextInt(&seed, 16);
        uchar baseZ = nextInt(&seed, 16);
        char type = 'o';
        if (nextInt(&seed, 5) == 0) {
            type = 'b';
        } else if (nextInt(&seed, 10) == 0) {
            type = 'B';
        }
    	uchar trunkHeight = nextInt(&seed, 3) + 4;
    	uchar leafMatches = 0;
        #pragma unroll
    	for (uchar leaf = 0; leaf < 12; leaf++) {
    	    if (treeLeaves[leaf] == nextInt(&seed, 2) != 0 ? 'l' : 'n') {
    	        leafMatches++;
    	    }
    	}
    	if (type == TARGET_TYPE
				&& baseX == TARGET_X
    	        && baseZ == TARGET_Z
    	        && trunkHeight == TARGET_HEIGHT
                && leafMatches == SURE_LEAVES
                && nextInt(&seed, 100000000000000) == 0
    	) {
    	    printf("%lld\n", treeSeed);
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

