/* Compile: mex DataHash_v2_core.cpp -I./xxHash-0.8.2
   Call:    hash = DataHash_v2_core(data)
   Help of cpp in matlab: https://ww2.mathworks.cn/help/matlab/matlab_external/c-mex-source-file.html
 */
#include <stdio.h>
#include <string.h> /* For strcmp() */
#include <stdlib.h> /* For EXIT_FAILURE, EXIT_SUCCESS */
#include "xxhash.h" // xxHash, a fast hash. --https://github.com/Cyan4973/xxHash
#include "xxh3.h"
#include "mex.hpp"
#include "mexAdapter.hpp"

using namespace matlab::data;
using matlab::mex::ArgumentList;

// inputs: path,var, nlhs=0,nrhs=2
class MexFunction : public matlab::mex::Function{
    void operator()(ArgumentList outputs, ArgumentList inputs) {    // main func
        unsigned long int seed = 0;
        matlab::data::ArrayFactory factory;
        TypedArray<uint8_t> bytestream = std::move(inputs[0]);
        size_t nbytes = bytestream.getNumberOfElements();   // numel(A), must call before release
        buffer_ptr_t<uint8_t> bytestream_bf = bytestream.release();
        unsigned char* pbytestream = bytestream_bf.get();
        XXH64_hash_t hash = XXH64(pbytestream, nbytes, seed);
        // hash = pbytestream[nbytes-1];
        TypedArray<uint64_t> mathash = factory.createScalar<uint64_t>(hash);
        outputs[0] = mathash;
    };
};
