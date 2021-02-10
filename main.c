#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <signal.h>
#include <time.h>

#define CL_TARGET_OPENCL_VERSION 220
#pragma OPENCL EXTENSION cl_khr_icd : enable

#ifdef __APPLE__
#include <OpenCL/opencl.h>
#else
#include <CL/cl.h>
#endif

#include "nanos.h"

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
#define SEEDSPACE_MAX (1LLU << 44) // aka 2^48
#define SEEDS_PER_KERNEL (1 << 18)
#define THREAD_BATCH_SIZE 1024
#define BLOCK_SIZE 8
#define TOTAL_KERNELS (SEEDSPACE_MAX / SEEDS_PER_KERNEL)

#define STARTS_LEN        (THREAD_BATCH_SIZE * sizeof(uint64_t))
#define ENDS_LEN          (THREAD_BATCH_SIZE * sizeof(uint64_t))
#define RESULTS_LEN       (THREAD_BATCH_SIZE * sizeof(uint64_t) * SEEDS_PER_KERNEL)
#define RESULTS_COUNT_LEN (THREAD_BATCH_SIZE * sizeof(size_t))

void checkcl(const char *fn, int err) {
    if (err != CL_SUCCESS) {
        fprintf(stderr, "%s error: %d\n", fn, err); 
        fflush(stdout);
        fflush(stderr);
        exit(-1);
    }
}

volatile int interrupted = 0;

void interrupt(int signal) {
    interrupted = 1;
}

int main(int argc, char** argv) {
    // source file variables
    FILE *source_file;
    char *source_str;
    size_t source_size;

    signal(SIGINT, interrupt);

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
    cl_mem d_results_count;
    uint64_t *starts = malloc(STARTS_LEN);
    uint64_t *ends = malloc(ENDS_LEN);
    uint64_t *results = malloc(RESULTS_LEN);
    size_t *results_count = malloc(RESULTS_COUNT_LEN);
    uint64_t kernel_offset = 0;

    FILE *results_file;
    FILE *progress_file;

    progress_file = fopen("progress", "rb");
    if (progress_file != NULL) {
        fread(&kernel_offset, sizeof(uint64_t), 1, progress_file);
        fclose(progress_file);
        remove("progress");
    }

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
    d_results_count = clCreateBuffer(context, CL_MEM_WRITE_ONLY, RESULTS_COUNT_LEN, NULL, &err);
    checkcl("results count create", err);

    //uint64_t time_start = nanos();
    printf("started at ctime: %llu\n", time(0));

    for (; kernel_offset < TOTAL_KERNELS; kernel_offset += THREAD_BATCH_SIZE) {
        // generate kernel parameters
        uint64_t time_start = nanos();

        if (SEEDSPACE_MAX % SEEDS_PER_KERNEL != 0) {
            fprintf(stderr, "seedspace_max (%llu) is not divisible by seeds per kernel (%llu)!", SEEDSPACE_MAX, SEEDS_PER_KERNEL);
            exit(-1);
        }
        for (uint64_t kernel = kernel_offset; kernel < kernel_offset + THREAD_BATCH_SIZE; kernel++) {
            uint64_t rel_kernel = kernel - kernel_offset;
            starts[rel_kernel] = kernel * SEEDS_PER_KERNEL;
            ends[rel_kernel] = (kernel + 1) * SEEDS_PER_KERNEL - 1;
            //printf("[HOST] spawned thread id %6d with start %12d and end %12d\n", kernel, starts[rel_kernel], ends[rel_kernel]);
        }

        printf("work dist took %.6f\n", (nanos() - time_start) / 1e9);
        fflush(stdout);
        time_start = nanos();

		// write to kernel param buffers
        checkcl("starts write", clEnqueueWriteBuffer(queue, d_starts, CL_FALSE, 0, STARTS_LEN, starts, 0, NULL, NULL));
        checkcl("ends write", clEnqueueWriteBuffer(queue, d_ends, CL_FALSE, 0, ENDS_LEN, ends, 0, NULL, NULL));

        // create the kernel itself
        checkcl("kernel arg set 0", clSetKernelArg(kernel, 0, sizeof(d_starts), &d_starts));
        checkcl("kernel arg set 1", clSetKernelArg(kernel, 1, sizeof(d_ends), &d_ends));
        checkcl("kernel arg set 2", clSetKernelArg(kernel, 2, sizeof(d_results), &d_results));
        checkcl("kernel arg set 3", clSetKernelArg(kernel, 3, sizeof(d_results_count), &d_results_count));
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
        checkcl("clEnqueueReadBuffer", clEnqueueReadBuffer(queue, d_results_count, CL_FALSE, 0, RESULTS_COUNT_LEN, results_count, 0, NULL, NULL));

		checkcl("clFlush", clFlush(queue));
        checkcl("clFinish", clFinish(queue));

        double kernel_time = (nanos() - time_start) / 1e9;
        printf("kernel batch took %.6f\n", kernel_time);
        time_start = nanos();

        for (size_t i = 0; i < THREAD_BATCH_SIZE; i++) {
            for (size_t j = 0; j < results_count[i]; j++) {
                if (results[i] != (uint64_t) -1) {
                    //printf("%llu\n", results[i]);
                    uint64_t result = results[i];
                    fwrite(&result, sizeof(uint64_t), 1, results_file);
                }
            }
        }

        printf("results write took %.6f\n", (nanos() - time_start) / 1e9);
        printf("running at %.3f sps\n", (SEEDS_PER_KERNEL * THREAD_BATCH_SIZE) / kernel_time);
        printf("progress: %15llu/%15llu, %6.2f%%\n", ends[THREAD_BATCH_SIZE-1], SEEDSPACE_MAX, (double) ends[THREAD_BATCH_SIZE-1] / SEEDSPACE_MAX) * 100;

        fflush(stdout);

        if (interrupted) {
            printf("interrupted - saving progress\n");
            progress_file = fopen("progress", "wb");
            fwrite(&kernel_offset, sizeof(uint64_t), 1, progress_file);
            fflush(stdout);
            fflush(progress_file);
            fclose(progress_file);
            fflush(results_file);
            fclose(results_file);
            exit(0);
        }
    }
    fflush(results_file);
    fclose(results_file);

    fflush(stdout);
    exit(0);
} 
