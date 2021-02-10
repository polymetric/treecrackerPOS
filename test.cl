kernel void test(global long *starts, global long *ends, global long *results, global size_t *results_count) {
    int id = get_global_id(0);
    long start = starts[id];
    long end = ends[id];
    long result = 0;
    //printf("[DEVICE] spawned thread id %6lld with start %12lld and end %12lld\n", id, start, end);
    printf("put result %15llu at index %15llu\n", 0x0011223344556677, id);
    results[id * 8] = id;
    results[id * 8 + 1] = id * 2;
    results_count[id] = 2;
}
