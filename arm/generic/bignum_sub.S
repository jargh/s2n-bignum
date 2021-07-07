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
// Subtract, z := x - y
// Inputs x[m], y[n]; outputs function return (carry-out) and z[p]
//
//    extern uint64_t bignum_sub
//     (uint64_t p, uint64_t *z,
//      uint64_t m, uint64_t *x, uint64_t n, uint64_t *y);
//
// Does the z := x - y operation, truncating modulo p words in general and
// returning a top borrow (0 or 1) in the p'th place, only subtracting input
// words below p (as well as m and n respectively) to get the diff and borrow.
//
// Standard ARM ABI: X0 = p, X1 = z, X2 = m, X3 = x, X4 = n, X5 = y, returns X0
// ----------------------------------------------------------------------------

#define p x0
#define z x1
#define m x2
#define x x3
#define n x4
#define y x5
#define i x6
#define a x7
#define d x8

.text
.globl bignum_sub

bignum_sub:

// First clamp the two input sizes m := min(p,m) and n := min(p,n) since
// we'll never need words past the p'th. Can now assume m <= p and n <= p.
// Then compare the modified m and n and branch accordingly

                cmp     m, p
                csel    m, p, m, cs
                cmp     n, p
                csel    n, p, n, cs
                cmp     m, n
                bcc     ylonger

// The case where x is longer or of the same size (p >= m >= n)

                sub     p, p, m
                sub     m, m, n
                subs    i, xzr, xzr
                cbz     n, xmainskip
xmainloop:
                ldr     a, [x, i, LSL 3]
                ldr     d, [y, i, LSL 3]
                sbcs    a, a, d
                str     a, [z, i, LSL 3]
                add     i, i, 1
                sub     n, n, 1
                cbnz    n, xmainloop
xmainskip:
                cbz     m, xtopskip
xtoploop:
                ldr     a, [x, i, LSL 3]
                sbcs    a, a, xzr
                str     a, [z, i, LSL 3]
                add     i, i, 1
                sub     m, m, 1
                cbnz    m, xtoploop
xtopskip:
                cbnz    p, tails
                cset    x0, cc
                ret

// The case where y is longer (p >= n > m)

ylonger:
                sub     p, p, n
                sub     n, n, m
                subs    i, xzr, xzr
                cbz     m, ytoploop
ymainloop:
                ldr     a, [x, i, LSL 3]
                ldr     d, [y, i, LSL 3]
                sbcs    a, a, d
                str     a, [z, i, LSL 3]
                add     i, i, 1
                sub     m, m, 1
                cbnz    m, ymainloop
ytoploop:
                ldr     a, [y, i, LSL 3]
                sbcs    a, xzr, a
                str     a, [z, i, LSL 3]
                add     i, i, 1
                sub     n, n, 1
                cbnz    n, ytoploop
ytopskip:
                cbnz    p, tails
                cset    x0, cc
                ret

// Adding a non-trivial tail, when p > max(m,n)

tails:
                csetm   a, cc
tailloop:
                str     a, [z, i, LSL 3]
                add     i, i, 1
                subs    p, p, 1
                bne     tailloop
                neg     x0, a
                ret