#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <signal.h>
#include <time.h>
#include <sys/time.h>

#define CL_TARGET_OPENCL_VERSION 220
#pragma OPENCL EXTENSION cl_khr_icd : enable
#pragma OPENCL EXTENSION cl_khr_int64_base_atomics : enable

#ifdef __APPLE__
#include <OpenCL/opencl.h>
#else
#include <CL/cl.h>
#endif

#include "nanos.h"

#define DEVICE_TYPE             CL_DEVICE_TYPE_GPU

#define SOURCE_FILENAME         "trees.cl"
#define KERNEL_PRIM_NAME        "filter_prim"
#define KERNEL_AUX_NAME         "filter_aux"

#define RESULTS_FILE_PATH       "treeseeds.bin"
#define PROGRESS_FILE_PATH      "progress"

#define SEEDSPACE_MAX           (1LLU << 44)
// apparently, at least on windows, THREAD_BATCH_SIZE can't be 2^32 because
// it overflows or something and makes the kernel ids like 2^64 or somethin
// TODO see if this happens on linux
#define THREAD_BATCH_SIZE       (1LLU << 31)
#define BLOCK_SIZE              (1LLU << 10)

#define RESULTS_PRIM_LEN        (THREAD_BATCH_SIZE * sizeof(uint64_t) / 10)
#define RESULTS_PRIM_COUNT_LEN  (sizeof(uint32_t))

#define RESULTS_AUX_LEN         (THREAD_BATCH_SIZE * sizeof(uint64_t) / 100)
#define RESULTS_AUX_COUNT_LEN   (sizeof(uint32_t))

void checkcl(const char *fn, int err) {
    if (err != CL_SUCCESS) {
        fprintf(stderr, "%s error: %d\n", fn, err); 
        fflush(stdout);
        fflush(stderr);
        exit(-1);
    }
}

int main(int argc, char** argv) {
    // source file variables
    FILE *source_file;
    char *source_str;
    size_t source_size;

    // load program source
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
    memset(source_str, 0, source_size + 1);
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
    cl_kernel kernel_prim;
    cl_kernel kernel_aux;
    
    // host & device memory objects for
    // primary filter results
    cl_mem d_results_prim;
//    uint64_t *results_prim = malloc(RESULTS_PRIM_LEN); 
    // number of primary filter results
    cl_mem d_results_prim_count;
    uint32_t results_prim_count;
    // auxiliary filter results
    cl_mem d_results_aux;
    uint64_t *results_aux = malloc(RESULTS_AUX_LEN);
    // number of auxiliary filter results
    cl_mem d_results_aux_count;
    uint32_t results_aux_count;
    cl_mem d_kernel_offset;
    uint64_t kernel_offset = 0;

    uint64_t total_results = 0;

    // if there was a kernel in progress that was interrupted,
    // restore its progress
    FILE *results_file;
    FILE *progress_file;

    progress_file = fopen(PROGRESS_FILE_PATH, "rb");
    int restored = 0;
    if (progress_file != NULL) {
        restored = 1;
        fread(&kernel_offset, sizeof(uint64_t), 1, progress_file);
        fclose(progress_file);
        remove("progress");
    }
    
    if (restored) {
        results_file = fopen(RESULTS_FILE_PATH, "ab");
    } else if (fopen(RESULTS_FILE_PATH, "r") != NULL) {
        printf("existing results file found. please delete or rename it to continue\n");
        exit(1);
    } else {
        // if there was no existing results file
        // we just want to create the file and write straight to it
        results_file = fopen(RESULTS_FILE_PATH, "wb");
    }

    progress_file = fopen(PROGRESS_FILE_PATH, "wb");

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
    // print build log if there was an error
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

    // create primary & auxiliary filter kernel
    kernel_prim = clCreateKernel(program, KERNEL_PRIM_NAME, &err);
    checkcl("clCreateKernel prim", err);
    kernel_aux = clCreateKernel(program, KERNEL_AUX_NAME, &err);
    checkcl("clCreateKernel aux", err);

    // create buffer for primary results
    d_results_prim = clCreateBuffer(context, CL_MEM_READ_WRITE, RESULTS_PRIM_LEN, NULL, &err);
    checkcl("results prim create", err);
    d_results_prim_count = clCreateBuffer(context, CL_MEM_READ_WRITE, RESULTS_PRIM_COUNT_LEN, NULL, &err);
    checkcl("results prim count create", err);
    // and aux
    d_results_aux = clCreateBuffer(context, CL_MEM_WRITE_ONLY, RESULTS_AUX_LEN, NULL, &err);
    checkcl("results aux create", err);
    d_results_aux_count = clCreateBuffer(context, CL_MEM_WRITE_ONLY, RESULTS_AUX_COUNT_LEN, NULL, &err);
    checkcl("results aux count create", err);

    d_kernel_offset = clCreateBuffer(context, CL_MEM_WRITE_ONLY, sizeof(kernel_offset), NULL, &err);
    checkcl("kernel offset create", err);

    // main kernel loop
    uint64_t time_global_start = nanos();
    uint64_t time_last;
    uint64_t time_batch_start;
    // slightly cursed for loop, we don't actually set the kernel offset here
    // because we initialized it to zero before, and if we restore progress
    // we just set it to the saved value
    for (; kernel_offset < SEEDSPACE_MAX; kernel_offset += THREAD_BATCH_SIZE) {
        time_batch_start = nanos();
        time_last = nanos();

        // zero out counters
        results_prim_count = 0;
        results_aux_count = 0;
        checkcl("reset prim counter", clEnqueueWriteBuffer(queue, d_results_prim_count, CL_TRUE, 0, RESULTS_PRIM_COUNT_LEN, &results_prim_count, 0, NULL, NULL));
        checkcl("reset aux counter", clEnqueueWriteBuffer(queue, d_results_aux_count, CL_TRUE, 0, RESULTS_AUX_COUNT_LEN, &results_aux_count, 0, NULL, NULL));
        checkcl("write kernel offset", clEnqueueWriteBuffer(queue, d_kernel_offset, CL_TRUE, 0, sizeof(kernel_offset), &kernel_offset, 0, NULL, NULL));

        // queue the primary filter kernel for execution
        checkcl("kernel arg set 0", clSetKernelArg(kernel_prim, 0, sizeof(d_kernel_offset), &d_kernel_offset));
        checkcl("kernel arg set 1", clSetKernelArg(kernel_prim, 1, sizeof(d_results_prim), &d_results_prim));
        checkcl("kernel arg set 2", clSetKernelArg(kernel_prim, 2, sizeof(d_results_prim_count), &d_results_prim_count));
        size_t global_dimensions = THREAD_BATCH_SIZE;
        size_t block_size = BLOCK_SIZE;
        checkcl("clEnqueueNDRangeKernel prim", clEnqueueNDRangeKernel(
                queue,                  // command queue
                kernel_prim,            // kernel
                1,                      // work dimensions
                NULL,                   // global work offset
                &global_dimensions,     // global work size
                &block_size,            // local work size (NULL = auto)
                0,                      // number of events in wait list
                NULL,                   // event wait list
                NULL                    // event
        ));

        // wait for primary kernel to finish
		checkcl("clFlush", clFlush(queue));
        checkcl("clFinish kernel queue", clFinish(queue));
        
        // read results count
        // TODO figure out why tf this segfaults
        // i just moved it to below the wait for the kernel to finish calls
        // it might have been because of that, we'll see - it hasn't happened in
        // a while
        checkcl("clEnqueueReadBuffer queue read prim results count", clEnqueueReadBuffer(queue, d_results_prim_count, CL_TRUE, 0, RESULTS_PRIM_COUNT_LEN, &results_prim_count, 0, NULL, NULL));

        // measure primary kernel time
        double kernel_prim_time = (nanos() - time_last) / 1e9;
        printf("primary kernel batch took %.6f\n", kernel_prim_time);
        time_last = nanos();

        printf("got %8u results from primary batch\n", results_prim_count);

        // run the aux kernel only if we got results from the initial filter
        if (results_prim_count > 0) {
            // and queue the auxiliary filter kernel
            checkcl("kernel arg set 0", clSetKernelArg(kernel_aux, 0, sizeof(d_results_prim), &d_results_prim));
            checkcl("kernel arg set 1", clSetKernelArg(kernel_aux, 1, sizeof(d_results_prim_count), &d_results_prim_count));
            checkcl("kernel arg set 2", clSetKernelArg(kernel_aux, 2, sizeof(d_results_aux), &d_results_aux));
            checkcl("kernel arg set 3", clSetKernelArg(kernel_aux, 3, sizeof(d_results_aux_count), &d_results_aux_count));
            global_dimensions = results_prim_count;
            block_size = BLOCK_SIZE;
            checkcl("clEnqueueNDRangeKernel aux", clEnqueueNDRangeKernel(
                    queue,                  // command queue
                    kernel_aux,             // kernel
                    1,                      // work dimensions
                    NULL,                   // global work offset
                    &global_dimensions,     // global work size
                    NULL,                   // local work size (NULL = auto)
                    0,                      // number of events in wait list
                    NULL,                   // event wait list
                    NULL                    // event
            ));
            
            // read aux results count
            checkcl("clEnqueueReadBuffer queue read aux results count", clEnqueueReadBuffer(queue, d_results_aux_count, CL_FALSE, 0, RESULTS_AUX_COUNT_LEN, &results_aux_count, 0, NULL, NULL));

            // wait for aux kernel to finish
            checkcl("clFlush", clFlush(queue));
            checkcl("clFinish kernel queue", clFinish(queue));

            // measure aux kernel time
            double kernel_aux_time = (nanos() - time_last) / 1e9;
            printf("aux kernel batch took %.6f\n", kernel_aux_time);
            time_last = nanos();

            printf("got %8u results from aux batch\n", results_aux_count);

            // queue aux result read
            checkcl("clEnqueueReadBuffer queue read aux results", clEnqueueReadBuffer(queue, d_results_aux, CL_FALSE, 0, results_aux_count * sizeof(uint64_t), results_aux, 0, NULL, NULL));

            // wait for the results to be read
            checkcl("clFlush", clFlush(queue));
            checkcl("clFinish read aux results", clFinish(queue));

            // measure result read time
            printf("mem read took %.6f\n", (nanos() - time_last) / 1e9);
            time_last = nanos();

            // write results to file
            for (size_t i = 0; i < results_aux_count; i++) {
                uint64_t result = results_aux[i];
                fwrite(&result, sizeof(uint64_t), 1, results_file);
            }
            fflush(results_file);

            // measure result write time
            printf("results write took %.6f\n", (nanos() - time_last) / 1e9);
        } else {
            printf("got 0 results from primary kernel, skipping aux kernel\n");
        }

        // print speed & progress
        printf("running at %.3f sps\n", (THREAD_BATCH_SIZE / ((nanos() - time_batch_start) / 1e9)));
        printf("progress: %15llu/%15llu, %6.2f%%\n\n", kernel_offset + THREAD_BATCH_SIZE, SEEDSPACE_MAX, (double) (kernel_offset + THREAD_BATCH_SIZE) / SEEDSPACE_MAX * 100);

        fflush(stdout);

        // write progress in case we crash or cancel
        fwrite(&kernel_offset, sizeof(kernel_offset), 1, progress_file);
        fflush(progress_file);
    }

    // close and delete progress file
    fclose(progress_file);
    remove(PROGRESS_FILE_PATH);

    // make sure results file is flushed and closed
    // as a precaution
    fflush(results_file);
    fclose(results_file);

    fflush(stdout);
    exit(0);
} 
