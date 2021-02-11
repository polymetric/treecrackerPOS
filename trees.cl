// IMPORTANT
// don't forget to change the primary tree's target x!
#define PRIM_TARGET_X 15

// this is the maximum number of calls that each tree can be from each other
#define TREE_CALL_RANGE 200

#define AUX_TREE_COUNT 3
#define TARGET_TREE_FLAGS ((1 << AUX_TREE_COUNT) - 1)

// RNG stuff
#define MASK ((1LU << 48) - 1)
#define fwd_1(seed) (seed = (seed *     25214903917LU +              11LU) & MASK)
#define rev_1(seed) (seed = (seed * 246154705703781LU + 107048004364969LU) & MASK)

// this is the initial filter stage that narrows down the seedspace from
// 2^44 to however many seeds can generate this tree
// this should use the tree with the most information
kernel void filter_prim(global ulong *kernel_offset, global ulong *results_prim, global uint *results_prim_count) {
    // the global ID of this kernel is the lower 44 bits of the seed that
    // it's going to check. we just or that with the target X value
    // because we know the first seed for this tree should contain that value
    //
    // note: CL ids are size_t, so they should be big enough
    // if they're not that could be a bug on 32 bit machines :/
    ulong seed = (get_global_id(0) + *kernel_offset) | ((ulong) PRIM_TARGET_X << 44);

    // precalculated RNG steps for the primary tree
    if ((((seed *     25214903917LU +              11LU) >> 44) & 15) != 15) return;
    if ((((seed *  61282721086213LU +  25979478236433LU) >> 47) &  1) !=  0) return;
    if ((((seed * 128954768138017LU + 137139456763464LU) >> 47) &  1) !=  0) return;
    if ((((seed * 177269950146317LU + 148267022728371LU) >> 47) &  1) !=  0) return;
    if ((((seed *  92070806603349LU +  65633894156837LU) >> 47) &  1) !=  0) return;
    if ((((seed *  28158748839985LU + 233987836661708LU) >> 47) &  1) !=  0) return;
    if ((((seed * 118637304785629LU + 262259097190887LU) >> 47) &  1) !=  0) return;
    if ((((seed *  12659659028133LU + 156526639281273LU) >> 47) &  1) !=  0) return;
    if ((((seed * 120681609298497LU +  14307911880080LU) >> 47) &  1) !=  0) return;
    if ((((seed * 205749139540585LU +    277363943098LU) >> 17) %  5) ==  0) return;
    if ((((seed * 233752471717045LU +  11718085204285LU) >> 17) % 10) ==  0) return;
    if ((((seed *  55986898099985LU +  49720483695876LU) >> 17) %  3) !=  2) return;
    
    // if we make it past all those checks, save the seed
    // and increment the counter for the seeds we have found with the first
    // filter
    results_prim[*results_prim_count] = seed;
    atomic_add(results_prim_count, 1);
}

#define get_tree_flag(tree_flags, tree_id) ((tree_flags >> tree_id) & 1)
#define set_tree_flag(tree_flags, tree_id) (tree_flags |= 1 << tree_id)

#define check_tree(tree_id, target_x, target_z) {\
    if (get_tree_flag(tree_flags, 0) == 0\
            && tree_x == target_x\
            && tree_z == target_z\
    ) {\
    \
        tree_flags |= check_tree_aux_##tree_id(seed) << tree_id;\
   }\
}

uchar check_tree_aux_0(ulong seed) {
    // precalculated RNG steps for aux tree
    if ((((seed *     25214903917LU +              11LU) >> 44) & 15) != 11) return 0;
    if ((((seed * 120950523281469LU + 102626409374399LU) >> 47) &  1) !=  1) return 0;
    if ((((seed * 128954768138017LU + 137139456763464LU) >> 47) &  1) !=  0) return 0;
    if ((((seed * 177269950146317LU + 148267022728371LU) >> 47) &  1) !=  0) return 0;
    if ((((seed *  28158748839985LU + 233987836661708LU) >> 47) &  1) !=  1) return 0;
    if ((((seed * 118637304785629LU + 262259097190887LU) >> 47) &  1) !=  0) return 0;
    if ((((seed *  12659659028133LU + 156526639281273LU) >> 47) &  1) !=  1) return 0;
    if ((((seed * 120681609298497LU +  14307911880080LU) >> 47) &  1) !=  1) return 0;
    if ((((seed * 205749139540585LU +    277363943098LU) >> 17) %  5) ==  0) return 0;
    if ((((seed * 233752471717045LU +  11718085204285LU) >> 17) % 10) ==  0) return 0;
    if ((((seed *  55986898099985LU +  49720483695876LU) >> 17) %  3) !=  0) return 0;

    return 1;
}

uchar check_tree_aux_1(ulong seed) {
    // precalculated RNG steps for aux tree
    if ((((seed *     25214903917LU +              11LU) >> 44) & 15) != 15) return 0;
    if ((((seed *  55986898099985LU +  49720483695876LU) >> 47) &  1) !=  0) return 0;
    if ((((seed *  76790647859193LU +  25707281917278LU) >> 47) &  1) !=  1) return 0;
    if ((((seed * 128954768138017LU + 137139456763464LU) >> 47) &  1) !=  1) return 0;
    if ((((seed *  19927021227657LU + 127911637363266LU) >> 47) &  1) !=  0) return 0;
    if ((((seed *  28158748839985LU + 233987836661708LU) >> 47) &  1) !=  0) return 0;
    if ((((seed * 127636996050457LU + 159894566279526LU) >> 47) &  1) !=  0) return 0;
    if ((((seed * 205749139540585LU +    277363943098LU) >> 17) %  5) !=  0) return 0;
    if ((((seed * 233752471717045LU +  11718085204285LU) >> 17) %  3) !=  1) return 0;

    return 1;
}

uchar check_tree_aux_2(ulong seed) {
    // precalculated RNG steps for aux tree
    if ((((seed *     25214903917LU +              11LU) >> 44) & 15) !=  8) return 0;
    if ((((seed * 128954768138017LU + 137139456763464LU) >> 47) &  1) !=  1) return 0;
    if ((((seed *  28158748839985LU + 233987836661708LU) >> 47) &  1) !=  0) return 0;
    if ((((seed * 118637304785629LU + 262259097190887LU) >> 47) &  1) !=  1) return 0;
    if ((((seed *  12659659028133LU + 156526639281273LU) >> 47) &  1) !=  0) return 0;
    if ((((seed * 120681609298497LU +  14307911880080LU) >> 47) &  1) !=  1) return 0;
    if ((((seed * 205749139540585LU +    277363943098LU) >> 17) %  5) ==  0) return 0;
    if ((((seed * 233752471717045LU +  11718085204285LU) >> 17) % 10) ==  0) return 0;
    if ((((seed *  55986898099985LU +  49720483695876LU) >> 17) %  3) !=  1) return 0;

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
        global uint  *results_aux_count
) {
    ulong seed = results_prim[get_global_id(0)];
    
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
    for (int call_offset = 0; call_offset < TREE_CALL_RANGE; call_offset++) {
        tree_x = (fwd_1(seed) >> 44) & 15; // nextInt(16)
        tree_z = (fwd_1(seed) >> 44) & 15; // nextInt(16)

        check_tree(0,  0, 11); // L6
        check_tree(1,  6, 15); // L5
        check_tree(2,  5,  8); // L4

        rev_1(seed);
    }
    
    // if all the flags are set, we found a very good candidate seed
    if (tree_flags == TARGET_TREE_FLAGS) {
        results_aux[*results_aux_count] = results_prim[get_global_id(0)];
        atomic_add(results_aux_count, 1);
    }
}
