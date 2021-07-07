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
// Optionally negate, z := -x (if p nonzero) or z := x (if p zero)
// Inputs p, x[k]; outputs function return (nonzero input) and z[k]
//
//    extern uint64_t bignum_optneg
//     (uint64_t k, uint64_t *z, uint64_t p, uint64_t *x);
//
// It is assumed that both numbers x and z have the same size k digits.
// Returns a carry, which is equivalent to "x is nonzero".
//
// Standard ARM ABI: X0 = k, X1 = z, X2 = p, X3 = x, returns X0
// ----------------------------------------------------------------------------

#define k x0
#define z x1
#define p x2
#define x x3

#define a x4
#define i x5

.text
.globl bignum_optneg

bignum_optneg:

// if k = 0 do nothing. This also has the right top carry zero in x0

                cbz     k, end

// Convert p into a strict bitmask

                cmp     p, xzr
                csetm   p, ne

// Generate an initial carry-in for the negating case only to add 1; this
// is because we are actually going to do complements of the words of x

                adds    xzr, p, p

// Main loop
                mov     i, xzr
loop:
                ldr     a, [x, i]
                eor     a, a, p
                adcs    a, a, xzr
                str     a, [z, i]
                add     i, i, 8
                sub     k, k, 1
                cbnz    k, loop

// Return carry flag, fixing up inversion for negative case

                adc     x0, xzr, xzr
                neg     p, p
                eor     x0, x0, p

end:
                ret