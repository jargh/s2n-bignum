/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "LICENSE" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

// ----------------------------------------------------------------------------
// Convert 4-digit (256-bit) bignum to/from big-endian form
// Input x[4]; output z[4]
//
//    extern void bignum_bigendian_4
//     (uint64_t z[static 4], uint64_t x[static 4]);
//
// The same function is given two other prototypes whose names reflect the
// treatment of one or other argument as a byte array rather than word array:
//
//    extern void bignum_frombytes_4
//     (uint64_t z[static 4], uint8_t x[static 32]);
//
//    extern void bignum_tobytes_4
//     (uint8_t z[static 32], uint64_t x[static 4]);
//
// The implementation works by loading in bytes and storing in words (i.e.
// stylistically it is "frombytes"); in the more common little-endian
// usage of ARM, this is just byte reversal.
//
// Standard ARM ABI: X0 = z, X1 = x
// ----------------------------------------------------------------------------

.text
.globl bignum_bigendian_4
.globl bignum_frombytes_4
.globl bignum_tobytes_4

#define z x0
#define x x1

#define d x2
#define dshort w2
#define a x3
#define c x4

.macro accumdigit dest, i
        ldrb    dshort, [x, 8 * \i + 7]
        extr    \dest, d, xzr, 8
        ldrb    dshort, [x, 8 * \i + 6]
        extr    \dest, d, \dest, 8
        ldrb    dshort, [x, 8 * \i + 5]
        extr    \dest, d, \dest, 8
        ldrb    dshort, [x, 8 * \i + 4]
        extr    \dest, d, \dest, 8
        ldrb    dshort, [x, 8 * \i + 3]
        extr    \dest, d, \dest, 8
        ldrb    dshort, [x, 8 * \i + 2]
        extr    \dest, d, \dest, 8
        ldrb    dshort, [x, 8 * \i + 1]
        extr    \dest, d, \dest, 8
        ldrb    dshort, [x, 8 * \i + 0]
        extr    \dest, d, \dest, 8
.endm

// The reads and writes are organized in mirror-image pairs (0-3 and 1-2)
// to allow x and z to point to the same buffer without using more
// intermediate registers.

bignum_bigendian_4:
bignum_frombytes_4:
bignum_tobytes_4:

// 0 and 3 words

                accumdigit a, 0
                accumdigit c, 3
                str     a, [z, 8*3]
                str     c, [z, 8*0]

// 1 and 2 words

                accumdigit a, 1
                accumdigit c, 2
                str     a, [z, 8*2]
                str     c, [z, 8*1]

                ret