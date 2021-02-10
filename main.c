#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

#define CL_TARGET_OPENCL_VERSION 220
#pragma OPENCL EXTENSION cl_khr_icd : enable

#ifdef __APPLE__
#include <OpenCL/opencl.h>
#else
#include <CL/cl.h>
#endif

#define DEVICE_TYPE CL_DEVICE_TYPE_GPU

#define SOURCE_FILENAME "trees.cl"
#define SOURCE_KERNELNAME "trees"

// we don't subtract one from SEEDSPACE_MAX because
// if we did it wouldn't be divisible by SEEDS_PER_KERNEL
// and i think technically it just wraps around to 0
// so technically we're just checking seed 0 twice
// except that probably doesn't happen because the range
// is inclusive-exclusive like an idiomatic for loop
// so maybe it's perfect lol
#define SEEDSPACE_MAX (1LL << 44) // aka 2^48
#define SEEDS_PER_KERNEL (1 << 17)
#define THREAD_BATCH_SIZE 1024
#define BLOCK_SIZE 8
#define TOTAL_KERNELS (SEEDSPACE_MAX / SEEDS_PER_KERNEL)

#define STARTS_LEN  (THREAD_BATCH_SIZE * sizeof(int64_t))
#define ENDS_LEN    (THREAD_BATCH_SIZE * sizeof(int64_t))
#define RESULTS_LEN (THREAD_BATCH_SIZE * sizeof(int64_t) * SEEDS_PER_KERNEL)

void checkcl(const char *fn, int err) {
    if (err != CL_SUCCESS) {
        fprintf(stderr, "%s error: %d\n", fn, err); 
        fflush(stdout);
        fflush(stderr);
        exit(-1);
    }
}

void delay(int ms) { 
    clock_t start = clock(); 
    while (clock() < start + ms) 
		;
}

int main(int argc, char** argv) {
    // source file variables
    FILE *source_file;
    char *source_str;
    size_t source_size;

    // load kernel
    source_file = fopen(SOURCE_FILENAME, "r");
    if (source_file == NULL) {
        perror("file error");
        exit(-1);
    }
    // get file size
    fseek(source_file, 0, SEEK_END);
    source_size = ftell(source_file);
    fseek(source_file, 0, SEEK_SET);
    source_str = malloc(source_size + 1);
    source_str[source_size] = '\0';
    fread(source_str, 1, source_size, source_file);
    fclose(source_file);

	// cl variables
	int err;

    cl_uint num_platforms;
    cl_platform_id platform;
    cl_device_id device;
    cl_context context;
    cl_command_queue queue;

    cl_program program;
    cl_kernel kernel;

    cl_mem d_starts;
    cl_mem d_ends;
    cl_mem d_results;
    int64_t *starts = malloc(STARTS_LEN);
    int64_t *ends = malloc(ENDS_LEN);
    int64_t *results = malloc(RESULTS_LEN);

    FILE *results_file;

    results_file = fopen("treeseeds.txt", "wb");

    // cl boilerplate
    // for now it just gets the first device of the first platform
    checkcl("clGetPlatformIDs", clGetPlatformIDs(1, &platform, NULL));
    checkcl("clGetDeviceIDs", clGetDeviceIDs(platform, DEVICE_TYPE, 1, &device, NULL));
    context = clCreateContext(NULL, 1, &device, NULL, NULL, &err);
    checkcl("clCreateContext", err);
    queue = clCreateCommandQueueWithProperties(context, device, 0, &err);
    checkcl("clCreateCommandQueue", err);

    // compile kernel
    program = clCreateProgramWithSource(context, 1, (const char **) &source_str, NULL, &err);
    checkcl("clCreateProgramWithSource", err);
    err = clBuildProgram(program, 0, NULL, NULL, NULL, NULL);
    if (err != CL_SUCCESS) {
        size_t log_size;
        clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, 0, NULL, &log_size);
        char *log = malloc(log_size);
        clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, log_size, log, NULL);
        fprintf(stderr, "%s\n", log);
        fflush(stdout);
        fflush(stderr);
        exit(-1);
    }
    kernel = clCreateKernel(program, SOURCE_KERNELNAME, &err);
    checkcl("clCreateKernel", err);

    // create buffers for kernel parameters
    d_starts = clCreateBuffer(context, CL_MEM_READ_ONLY, STARTS_LEN, NULL, &err);
    checkcl("starts create", err);
    d_ends = clCreateBuffer(context, CL_MEM_READ_ONLY, ENDS_LEN, NULL, &err);
    checkcl("ends create", err);

    // create buffer for results
    d_results = clCreateBuffer(context, CL_MEM_WRITE_ONLY, RESULTS_LEN, NULL, &err);
    checkcl("results create", err);

    printf("started kernels at %d\n", time(0));

    for (int64_t kernel_offset = 0; kernel_offset < TOTAL_KERNELS; kernel_offset += THREAD_BATCH_SIZE) {
        // generate kernel parameters

        if (SEEDSPACE_MAX % SEEDS_PER_KERNEL != 0) {
            fprintf(stderr, "seedspace_max (%lld) is not divisible by seeds per kernel (%lld)!", SEEDSPACE_MAX, SEEDS_PER_KERNEL);
            exit(-1);
        }
        for (int64_t kernel = kernel_offset; kernel < kernel_offset + THREAD_BATCH_SIZE; kernel++) {
            int64_t rel_kernel = kernel - kernel_offset;
            starts[rel_kernel] = kernel * SEEDS_PER_KERNEL;
            ends[rel_kernel] = (kernel + 1) * SEEDS_PER_KERNEL - 1;
            //printf("[HOST] spawned thread id %6d with start %12d and end %12d\n", kernel, starts[rel_kernel], ends[rel_kernel]);
        }
        fflush(stdout);

		// write to kernel param buffers
        checkcl("starts write", clEnqueueWriteBuffer(queue, d_starts, CL_FALSE, 0, STARTS_LEN, starts, 0, NULL, NULL));
        checkcl("ends write", clEnqueueWriteBuffer(queue, d_ends, CL_FALSE, 0, ENDS_LEN, ends, 0, NULL, NULL));

        // zero out results
        memset(results, 0xFF, RESULTS_LEN);
        checkcl("results write", clEnqueueWriteBuffer(queue, d_results, CL_FALSE, 0, RESULTS_LEN, results, 0, NULL, NULL));

        // create the kernel itself
        checkcl("kernel arg set 0", clSetKernelArg(kernel, 0, sizeof(d_starts), &d_starts));
        checkcl("kernel arg set 1", clSetKernelArg(kernel, 1, sizeof(d_ends), &d_ends));
        checkcl("kernel arg set 2", clSetKernelArg(kernel, 2, sizeof(d_results), &d_results));
        size_t global_dimensions = THREAD_BATCH_SIZE;
        size_t block_size = BLOCK_SIZE;
        checkcl("clEnqueueNDRangeKernel", clEnqueueNDRangeKernel(
                queue,                  // command queue
                kernel,                 // kernel
                1,                      // work dimensions
                NULL,                   // global work offset
                &global_dimensions,     // global work size
                &block_size,            // local work size (NULL = auto)
                0,                      // number of events in wait list
                NULL,                   // event wait list
                NULL                    // event
        ));
        
        checkcl("clEnqueueReadBuffer", clEnqueueReadBuffer(queue, d_results, CL_FALSE, 0, RESULTS_LEN, results, 0, NULL, NULL));

		checkcl("clFlush", clFlush(queue));
        checkcl("clFinish", clFinish(queue));

        for (int i = 0; i < THREAD_BATCH_SIZE * SEEDS_PER_KERNEL; i++) {
            if (results[i] != (int64_t) -1) {
                //printf("%lld\n", results[i]);
                int64_t result = results[i];
                fwrite(&result, sizeof(int64_t), 1, results_file);
            }
        }
    }

    fflush(stdout);
    exit(0);
} 
