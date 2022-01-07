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
// Montgomery multiply, z := (x * y / 2^256) mod p_256
// Inputs x[4], y[4]; output z[4]
//
//    extern void bignum_montmul_p256_alt
//     (uint64_t z[static 4], uint64_t x[static 4], uint64_t y[static 4]);
//
// Does z := (2^{-256} * x * y) mod p_256, assuming that the inputs x and y
// satisfy x * y <= 2^256 * p_256 (in particular this is true if we are in
// the "usual" case x < p_256 and y < p_256).
//
// Standard ARM ABI: X0 = z, X1 = x, X2 = y
// ----------------------------------------------------------------------------

        .globl  bignum_montmul_p256_alt
        .text
        .balign 4

// ---------------------------------------------------------------------------
// Core one-step "short" Montgomery reduction macro. Takes input in
// [d3;d2;d1;d0] and returns result in [d4;d3;d2;d1], adding to the
// existing contents of [d3;d2;d1] and generating d4 from zero, re-using
// d0 as a temporary internally together with t0, t1 and t2.
// It is fine for d4 to be the same register as d0, and it often is.
// ---------------------------------------------------------------------------

#define montreds(d4,d3,d2,d1,d0, t2,t1,t0)                                  \
/* Let w = d0, the original word we use as offset; d0 gets recycled      */ \
/* First let [t2;t1] = 2^32 * w                                          */ \
/* then let [d0;t0] = (2^64 - 2^32 + 1) * w (overwrite old d0)           */ \
                lsl     t1, d0, #32;                                        \
                subs    t0, d0, t1;                                         \
                lsr     t2, d0, #32;                                        \
                sbc     d0, d0, t2;                                         \
/* Hence [d4;..;d1] := [d3;d2;d1;0] + (2^256 - 2^224 + 2^192 + 2^96) * w */ \
                adds    d1, d1, t1;                                         \
                adcs    d2, d2, t2;                                         \
                adcs    d3, d3, t0;                                         \
                adc     d4, d0, xzr

#define z x0
#define x x1
#define y x2

#define a0 x3
#define a1 x4
#define a2 x5
#define a3 x6
#define b0 x7
#define b1 x8
#define b2 x9
#define b3 x10

#define h x11
#define l x12

#define u0 x13
#define u1 x14
#define u2 x15
#define u3 x16

// These alias to the input arguments when no longer needed

#define u4 a0
#define u5 a1
#define u6 a2
#define u7 a3

bignum_montmul_p256_alt:

// Load operands and set up row 0 = [u4;...;u0] = a0 * [b3;...;b0]

                ldp     a0, a1, [x]
                ldp     b0, b1, [y]

                mul     u0, a0, b0
                umulh   u1, a0, b0
                mul     l, a0, b1
                umulh   u2, a0, b1
                adds    u1, u1, l

                ldp     b2, b3, [y, #16]

                mul     l, a0, b2
                umulh   u3, a0, b2
                adcs    u2, u2, l

                mul     l, a0, b3
                umulh   u4, a0, b3
                adcs    u3, u3, l
                adc     u4, u4, xzr

                ldp     a2, a3, [x, #16]

// Row 1 = [u5;...;u0] = [a1;a0] * [b3;...;b0]

                mul     l, a1, b0
                umulh   h, a1, b0
                adds    u1, u1, l

                adcs    u2, u2, h
                mul     l, a1, b1
                umulh   h, a1, b1
                adc     h, h, xzr
                adds    u2, u2, l

                adcs    u3, u3, h
                mul     l, a1, b2
                umulh   h, a1, b2
                adc     h, h, xzr
                adds    u3, u3, l

                adcs    u4, u4, h
                mul     l, a1, b3
                umulh   h, a1, b3
                adc     h, h, xzr
                adds    u4, u4, l
                adc     u5, h, xzr

// Row 2 = [u6;...;u0] = [a2;a1;a0] * [b3;...;b0]

                mul     l, a2, b0
                umulh   h, a2, b0
                adds    u2, u2, l

                adcs    u3, u3, h
                mul     l, a2, b1
                umulh   h, a2, b1
                adc     h, h, xzr
                adds    u3, u3, l

                adcs    u4, u4, h
                mul     l, a2, b2
                umulh   h, a2, b2
                adc     h, h, xzr
                adds    u4, u4, l

                adcs    u5, u5, h
                mul     l, a2, b3
                umulh   h, a2, b3
                adc     h, h, xzr
                adds    u5, u5, l
                adc     u6, h, xzr

// Row 3 = [u7;...;u0] = [a3;...a0] * [b3;...;b0]

                mul     l, a3, b0
                umulh   h, a3, b0
                adds    u3, u3, l

                adcs    u4, u4, h
                mul     l, a3, b1
                umulh   h, a3, b1
                adc     h, h, xzr
                adds    u4, u4, l

                adcs    u5, u5, h
                mul     l, a3, b2
                umulh   h, a3, b2
                adc     h, h, xzr
                adds    u5, u5, l

                adcs    u6, u6, h
                mul     l, a3, b3
                umulh   h, a3, b3
                adc     h, h, xzr
                adds    u6, u6, l
                adc     u7, h, xzr

// Perform 4 Montgomery steps to rotate the lower half

                montreds(u0,u3,u2,u1,u0, h,l,y)
                montreds(u1,u0,u3,u2,u1, h,l,y)
                montreds(u2,u1,u0,u3,u2, h,l,y)
                montreds(u3,u2,u1,u0,u3, h,l,y)

// Add high and low parts, catching carry in y

                adds    u0, u0, u4
                adcs    u1, u1, u5
                adcs    u2, u2, u6
                adcs    u3, u3, u7
                cset    y, cs

// Set [h;0;l;-1] = p_256 and form [u7,u6,u5,u4] = [y;u3;u2;u1;u0] - p_256

                mov     l, #0x00000000ffffffff
                mov     h, #0xffffffff00000001

                subs    u4, u0, #-1
                sbcs    u5, u1, l
                sbcs    u6, u2, xzr
                sbcs    u7, u3, h
                sbcs    xzr, y, xzr

// Now CF is clear if the comparison carried so the original was fine
// Otherwise take the form with p_256 subtracted.

                csel    u0, u0, u4, cc
                csel    u1, u1, u5, cc
                csel    u2, u2, u6, cc
                csel    u3, u3, u7, cc

// Store back final result

                stp     u0, u1, [z]
                stp     u2, u3, [z, #16]

                ret

#if defined(__linux__) && defined(__ELF__)
.section .note.GNU-stack,"",%progbits
#endif