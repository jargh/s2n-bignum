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
// Shift bignum right by c < 64 bits z := floor(x / 2^c)
// Inputs x[n], c; outputs function return (bits shifted out) and z[k]
//
//    extern uint64_t bignum_shr_small
//     (uint64_t k, uint64_t *z, uint64_t n, uint64_t *x, uint64_t c);
//
// Does the "z := x >> c" operation where x is n digits, result z is p.
// The shift count c is masked to 6 bits so it actually uses c' = c mod 64.
// The return value is the inout mod 2^c'.
//
// Standard ARM ABI: X0 = k, X1 = z, X2 = n, X3 = x, X4 = c, returns X0
// ----------------------------------------------------------------------------

#define p x0
#define z x1
#define n x2
#define x x3
#define c x4

#define d x5
#define a x6
#define b x7
#define m x8
#define t x9

.text
.globl bignum_shr_small

bignum_shr_small:

// Set default carry-in word to 0

                mov     b, xzr

// First, if p > n then pad output on the left with p-n zeros

                cmp     n, p
                bcs     nopad
padloop:
                sub     p, p, 1
                str     xzr, [z, p, LSL 3]
                cmp     n, p
                bcc     padloop

// We now know that p <= n. If in fact p < n let carry word = x[p] instead of 0

nopad:
                beq     shiftstart
                ldr     b, [x, p, LSL 3]
shiftstart:

// Set up negated version of the shift and shift b in preparation.
// Use a mask for nonzero shift to fake 64-bit left shift in zero case

                neg     d, c
                lsl     b, b, d
                ands    xzr, c, 63
                csetm   m, ne
                and     b, b, m

// Now the main loop

                cbz     p, end
loop:
                sub     p, p, 1
                ldr     t, [x, p, LSL 3]
                lsr     a, t, c
                orr     a, a, b
                lsl     b, t, d
                and     b, b, m
                str     a, [z, p, LSL 3]
                cbnz    p, loop

// Return top word, shifted back to be a modulus

end:
                lsr     x0, b, d
                ret