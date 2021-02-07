kernel void test(global long *starts, global long *ends, global long *results) {
    int id = get_global_id(0);
    long start = starts[id];
    long end = ends[id];
    long result = 0;
    printf("[DEVICE] spawned thread id %6lld with start %12lld and end %12lld\n", id, start, end);
    results[id] = 1;
}
