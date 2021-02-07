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

#define SEEDSPACE_MAX ((1LL << 48) - 1)
#define THREAD_COUNT ((int64_t) 1e8)

#define STARTS_LEN  (THREAD_COUNT * sizeof(int64_t))
#define ENDS_LEN    (THREAD_COUNT * sizeof(int64_t))
#define RESULTS_LEN (THREAD_COUNT * sizeof(int64_t))

void checkcl(const char *fn, int err) {
    if (err != CL_SUCCESS) {
        fprintf(stderr, "%s error: %d\n", fn, err); 
        fflush(stdout);
        fflush(stderr);
        exit(-1);
    }
}

int main(int argc, char** argv) {
    // file variables
    FILE *file;
    char *source_str;
    size_t source_size;

    // load kernel
    file = fopen(SOURCE_FILENAME, "r");
    if (file == NULL) {
        perror("file error");
        exit(-1);
    }
    // get file size
    fseek(file, 0, SEEK_END);
    source_size = ftell(file);
    fseek(file, 0, SEEK_SET);
    source_str = malloc(source_size + 1);
    source_str[source_size] = '\0';
    fread(source_str, 1, source_size, file);
    fclose(file);
    
    // generate kernel parameters
    int64_t *starts = malloc(STARTS_LEN);
    int64_t *ends = malloc(ENDS_LEN);
    int64_t *results = malloc(RESULTS_LEN);

//    if (SEEDSPACE_MAX % THREAD_COUNT != 0) {
//        fprintf(stderr, "seedspace_max (%lld) is not divisible by thread count (%lld)!", SEEDSPACE_MAX, THREAD_COUNT);
//        exit(-1);
//    }
    for (int i = 0; i < THREAD_COUNT; i++) {
        starts[i] = (SEEDSPACE_MAX / THREAD_COUNT) * (i + 0) + 1;
        ends[i]   = (SEEDSPACE_MAX / THREAD_COUNT) * (i + 1) + 0;
        //printf("[HOST] spawned thread id %6d with start %12d and end %12d\n", i, starts[i], ends[i]);
    }

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
    
    // cl boilerplate
    // for now it just gets the first device of the first platform
    clGetPlatformIDs(0, NULL, &num_platforms);
    printf("platforms: %d\n", num_platforms);
    checkcl("clGetPlatformIDs 2", clGetPlatformIDs(1, &platform, NULL));
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
    checkcl("starts write", clEnqueueWriteBuffer(queue, d_starts, CL_FALSE, 0, STARTS_LEN, starts, 0, NULL, NULL));
    d_ends = clCreateBuffer(context, CL_MEM_READ_ONLY, ENDS_LEN, NULL, &err);
    checkcl("ends create", err);
    checkcl("ends write", clEnqueueWriteBuffer(queue, d_ends, CL_FALSE, 0, ENDS_LEN, ends, 0, NULL, NULL));

    // create buffer for results
    d_results = clCreateBuffer(context, CL_MEM_WRITE_ONLY, RESULTS_LEN, NULL, &err);
    checkcl("results create", err);

    // create the kernel itself
    checkcl("kernel arg set 0", clSetKernelArg(kernel, 0, sizeof(d_starts), &d_starts));
    checkcl("kernel arg set 1", clSetKernelArg(kernel, 1, sizeof(d_ends), &d_ends));
    checkcl("kernel arg set 2", clSetKernelArg(kernel, 2, sizeof(d_results), &d_results));
    size_t global_dimensions = THREAD_COUNT;
    checkcl("clEnqueueNDRangeKernel", clEnqueueNDRangeKernel(
            queue,                  // command queue
            kernel,                 // kernel
            1,                      // work dimensions
            NULL,                   // global work offset
            &global_dimensions,     // global work size
            NULL,                   // local work size (NULL = auto)
            0,                      // number of events in wait list
            NULL,                   // event wait list
            NULL                    // event
    ));
    
    printf("started kernels at %d\n", time(0));

    checkcl("clEnqueueReadBuffer", clEnqueueReadBuffer(queue, d_results, CL_FALSE, 0, RESULTS_LEN, results, 0, NULL, NULL));

    checkcl("clFinish", clFinish(queue));
} 
