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
// Add, z := x + y
// Inputs x[m], y[n]; outputs function return (carry-out) and z[p]
//
//    extern uint64_t bignum_add
//     (uint64_t p, uint64_t *z,
//      uint64_t m, uint64_t *x, uint64_t n, uint64_t *y);
//
// Does the z := x + y operation, truncating modulo p words in general and
// returning a top carry (0 or 1) in the p'th place, only adding the input
// words below p (as well as m and n respectively) to get the sum and carry.
//
// Standard x86-64 ABI: RDI = p, RSI = z, RDX = m, RCX = x, R8 = n, R9 = y,
// returns RAX
// ----------------------------------------------------------------------------


        .globl  bignum_add
        .text

#define p %rdi
#define z %rsi
#define m %rdx
#define x %rcx
#define n %r8
#define y %r9
#define i %r10
#define a %rax

#define ashort %eax



bignum_add:

// Zero the main index counter for both branches

                xorq    i, i

// First clamp the two input sizes m := min(p,m) and n := min(p,n) since
// we'll never need words past the p'th. Can now assume m <= p and n <= p.
// Then compare the modified m and n and branch accordingly

                cmpq    m, p
                cmovcq  p, m
                cmpq    n, p
                cmovcq  p, n
                cmpq    n, m
                jc      ylonger

// The case where x is longer or of the same size (p >= m >= n)

                subq    m, p
                subq    n, m
                incq    m
                testq   n, n
                jz      xtest
xmainloop:
                movq    (x,i,8), a
                adcq    (y,i,8), a
                movq    a, (z,i,8)
                incq    i
                decq    n
                jnz     xmainloop
                jmp     xtest
xtoploop:
                movq    (x,i,8), a
                adcq    $0, a
                movq    a, (z,i,8)
                incq    i
xtest:
                decq    m
                jnz     xtoploop
                movl    $0, ashort
                adcq    $0, a
                testq   p, p
                jnz     tails
                ret

// The case where y is longer (p >= n > m)

ylonger:

                subq    n, p
                subq    m, n
                testq   m, m
                jz      ytoploop
ymainloop:
                movq    (x,i,8), a
                adcq    (y,i,8), a
                movq    a, (z,i,8)
                incq    i
                decq    m
                jnz     ymainloop
ytoploop:
                movq    (y,i,8), a
                adcq    $0, a
                movq    a, (z,i,8)
                incq    i
                decq    n
                jnz     ytoploop
                movl    $0, ashort
                adcq    $0, a
                testq   p, p
                jnz     tails
                ret

// Adding a non-trivial tail, when p > max(m,n)

tails:
                movq    a, (z,i,8)
                xorq    a, a
                jmp     tail
tailloop:
                movq    a, (z,i,8)
tail:
                incq    i
                decq    p
                jnz     tailloop
                ret

#if defined(__linux__) && defined(__ELF__)
.section .note.GNU-stack,"",%progbits
#endif