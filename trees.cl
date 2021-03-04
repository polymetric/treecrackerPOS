// IMPORTANT
// don't forget to change the primary tree's target x!
#define PRIM_TARGET_X 9

// this is the maximum number of calls that each tree can be from each other
// if you change this you should recalculate the LCG values as well
// because i'm too lazy to make a macro that does that
#define TREE_CALL_RANGE 90

#define AUX_TREE_COUNT 5
#define TARGET_TREE_FLAGS ((1 << AUX_TREE_COUNT) - 1)

// RNG stuff
#define MASK ((1LU << 48) - 1)
#define fwd_1(seed)   (seed = (seed *     25214903917LU +              11LU) & MASK)
#define rev_1(seed)   (seed = (seed * 246154705703781LU + 107048004364969LU) & MASK)
#define rev_90(seed)  (seed = (seed *  50455039039097LU + 259439823819518LU) & MASK)

// this is the initial filter stage that narrows down the seedspace from
// 2^44 to however many seeds can generate this tree
// this should use the tree with the most information
kernel void filter_prim(global ulong *kernel_offset, global ulong *results_prim, volatile global uint *results_prim_count) {
    // the global ID of this kernel is the lower 44 bits of the seed that
    // it's going to check. we just or that with the target X value
    // because we know the first seed for this tree should contain that value
    //
    // note: CL ids are size_t, so they should be big enough
    // if they're not that could be a bug on 32 bit machines :/
    ulong seed = (get_global_id(0) + *kernel_offset) | ((ulong) PRIM_TARGET_X << 44);

    // precalculated RNG steps for the primary tree
    if ((((seed *     25214903917LU +              11LU) >> 44) & 15) !=  0) return ; // pos Z
    if ((((seed * 233752471717045LU +  11718085204285LU) >> 46) &  3) !=  3) return ; // height
    if ((((seed *  55986898099985LU +  49720483695876LU) >> 47) &  1) !=  1) return ; // base height
    if ((((seed *  76790647859193LU +  25707281917278LU) >> 47) &  1) !=  0) return ; // initial radius
    if (((((seed * 205749139540585LU +    277363943098LU) & 281474976710655LU) >> 17) %  3) ==  0) return ; // type


    // if we make it past all those checks, save the seed
    // and increment the counter for the seeds we have found with the first
    // filter
    results_prim[atomic_inc(results_prim_count)] = seed;
}

#define get_tree_flag(tree_flags, tree_id) ((tree_flags >> tree_id) & 1)
#define set_tree_flag(tree_flags, tree_id) (tree_flags |= 1 << tree_id)

#define check_tree(tree_id, target_x, target_z) {\
    if (get_tree_flag(tree_flags, tree_id) == 0\
            && tree_x == target_x\
            && tree_z == target_z\
    ) {\
    \
        tree_flags |= check_tree_aux_##tree_id(seed, iseed) << tree_id;\
   }\
}

uchar check_tree_aux_0(ulong seed, ulong iseed) {
    // precalculated RNG steps for aux tree
    if ((((seed * 233752471717045LU +  11718085204285LU) >> 47) &  1) !=  1) return 0; // base height
    if (((((seed *     25214903917LU +              11LU) & 281474976710655LU) >> 17) %  3) ==  0) return 0; // type

    return 1;
}

uchar check_tree_aux_1(ulong seed, ulong iseed) {
    // precalculated RNG steps for aux tree
    if ((((seed * 205749139540585LU +    277363943098LU) >> 46) &  3) !=  0) return 0; // height
    if ((((seed * 233752471717045LU +  11718085204285LU) >> 47) &  1) !=  0) return 0; // base height
    if ((((seed * 120950523281469LU + 102626409374399LU) >> 47) &  1) !=  1) return 0; // initial radius
    if (((((seed *     25214903917LU +              11LU) & 281474976710655LU) >> 17) %  3) ==  0) return 0; // type

    return 1;
}

uchar check_tree_aux_2(ulong seed, ulong iseed) {
    // precalculated RNG steps for aux tree
    if ((((seed * 205749139540585LU +    277363943098LU) >> 46) &  3) !=  0) return 0; // height
    if ((((seed * 233752471717045LU +  11718085204285LU) >> 47) &  1) !=  0) return 0; // base height
    if ((((seed * 120950523281469LU + 102626409374399LU) >> 47) &  1) !=  1) return 0; // initial radius
    if (((((seed *     25214903917LU +              11LU) & 281474976710655LU) >> 17) %  3) ==  0) return 0; // type

    return 1;
}

uchar check_tree_aux_3(ulong seed, ulong iseed) {
    // precalculated RNG steps for aux tree
    if ((((seed * 233752471717045LU +  11718085204285LU) >> 47) &  1) !=  0) return 0; // base height
    // if ((((seed *  55986898099985LU +  49720483695876LU) >> 47) &  1) !=  0) return 0; // radius
    if (((((seed *     25214903917LU +              11LU) & 281474976710655LU) >> 17) %  3) ==  0) return 0; // type

    return 1;
}

uchar check_tree_aux_4(ulong seed, ulong iseed) {
    // precalculated RNG steps for aux tree
    if (((((seed * 205749139540585LU +    277363943098LU) & 281474976710655LU) >> 17) %  3) ==  0) return -; // type

    return 1;
}

// this is the filter used to significantly narrow down the seeds we acquired
// with the first stage using the rest of the trees in the pop region
// we run this kernel once for every seed we found in the first stage
// this could potentially be made into a 2D kernel? with the first dimension
// being the seed and the second being the RNG sequence offset that we use to
// test the other tree
// but its 1D for now with a for loop
kernel void filter_aux(
        global ulong *results_prim,
        global uint  *results_prim_count,
        global ulong *results_aux,
        volatile global uint *results_aux_count
) {
    ulong seed = results_prim[get_global_id(0)];
    ulong iseed = seed;

    // we check in a range of -220 to +220 around the primary
    // tree seeds we found.
    // we do this by reversing that seed by 220 steps, then
    // we just check all 440 seeds after that
    rev_90(seed);

    // bit field for the trees that we find
    // the reason we use a bit field instead of a counter is so we can
    // check if a tree has already been found so we don't check it twice
    // and lose a couple cycles
    // 8 bits should be plenty but if you need more you can increase it
    // and you shouldn't have to change anything else
    uchar tree_flags = 0;

    // we loop thru the possible places that the aux trees could be
    // near the primary tree and check them
    uchar tree_x, tree_z;
    for (int call_offset = 0; call_offset < TREE_CALL_RANGE * 2; call_offset++) {
        tree_x = (fwd_1(seed) >> 44) & 15; // nextInt(16)
        tree_z = (fwd_1(seed) >> 44) & 15; // nextInt(16)

        check_tree(0,  8, 10);
        check_tree(1,  9,  5);
        check_tree(2,  4,  3);
        check_tree(3,  6, 13);
        check_tree(4, 13,  2);

        rev_1(seed);
    }



    // if all the flags are set, we found a very good candidate seed
    if (tree_flags == TARGET_TREE_FLAGS) {
        results_aux[atomic_inc(results_aux_count)] = results_prim[get_global_id(0)];
    }
}
