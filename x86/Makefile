#############################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0
#############################################################################

OSTYPE_RESULT=$(shell uname -s)
ARCHTYPE_RESULT=$(shell uname -m)

# Assembler directives that mark symbols as .hidden
# or .private_extern can be enabled by passing
# in the S2N_BN_HIDE_SYMBOLS parameter as:
#
#    make S2N_BN_HIDE_SYMBOLS=1
#

ifeq ($(S2N_BN_HIDE_SYMBOLS),1)
SYMBOL_HIDING=-DS2N_BN_HIDE_SYMBOLS=1
else
SYMBOL_HIDING=
endif

# Add explicit language input parameter to cpp, otherwise the use of #n for
# numeric literals in ARM code is a problem when used inside #define macros
# since normally that means stringization.
#
# Some clang-based preprocessors seem to behave differently, and get confused
# by single-quote characters in comments, so we eliminate // comments first.

ifeq ($(OSTYPE_RESULT),Darwin)
PREPROCESS=sed -e 's/\/\/.*//' | $(CC) -E -I../include -DWINDOWS_ABI=0 $(SYMBOL_HIDING) -xassembler-with-cpp -
else
ifeq ($(OSTYPE_RESULT),CYGWIN_NT-10.0)
PREPROCESS=$(CC) -E -I../include -DWINDOWS_ABI=1 $(SYMBOL_HIDING) -xassembler-with-cpp -
else
PREPROCESS=$(CC) -E -I../include -DWINDOWS_ABI=0 $(SYMBOL_HIDING) -xassembler-with-cpp -
endif
endif

# Generally GNU-type assemblers are happy with multiple instructions on
# a line, but we split them up anyway just in case.

SPLIT=tr ';' '\n'

# If actually on an x86 machine, just use the assembler (as). Otherwise
# use a cross-assembling version so that the code can still be assembled
# and the proofs checked against the object files (though you won't be able
# to run code without additional emulation infrastructure). For the clang
# version on OS X we just add the "-arch x86_64" option. For the Linux/gcc
# toolchain we assume the presence of the special cross-assembler. This
# can be installed via something like:
#
#  sudo apt-get install binutils-x86-64-linux-gnu

ifeq ($(ARCHTYPE_RESULT),x86_64)
ASSEMBLE=as
else
ifeq ($(OSTYPE_RESULT),Darwin)
ASSEMBLE=as -arch x86_64
else
ASSEMBLE=x86_64-linux-gnu-as
endif
endif

# Alternative preprocessing that forces WINDOWS_ABI=1
# This is used to generate additional .obj files purely
# for proof-checking, not used for actual code execution.

ifeq ($(OSTYPE_RESULT),Darwin)
WINPREPROCESS=sed -e 's/\/\/.*//' | $(CC) -E -I../include -DWINDOWS_ABI=1 -xassembler-with-cpp -
else
WINPREPROCESS=$(CC) -E -I../include -DWINDOWS_ABI=1 -xassembler-with-cpp -
endif

# List of object files for point operations and bignum operations

POINT_OBJ = curve25519/curve25519_ladderstep.o \
            curve25519/curve25519_ladderstep_alt.o \
            curve25519/curve25519_pxscalarmul.o \
            curve25519/curve25519_pxscalarmul_alt.o \
            curve25519/curve25519_x25519.o \
            curve25519/curve25519_x25519_alt.o \
            curve25519/curve25519_x25519base.o \
            curve25519/curve25519_x25519base_alt.o \
            curve25519/edwards25519_decode.o \
            curve25519/edwards25519_decode_alt.o \
            curve25519/edwards25519_encode.o \
            curve25519/edwards25519_epadd.o \
            curve25519/edwards25519_epadd_alt.o \
            curve25519/edwards25519_epdouble.o \
            curve25519/edwards25519_epdouble_alt.o \
            curve25519/edwards25519_pdouble.o \
            curve25519/edwards25519_pdouble_alt.o \
            curve25519/edwards25519_pepadd.o \
            curve25519/edwards25519_pepadd_alt.o \
            curve25519/edwards25519_scalarmulbase.o \
            curve25519/edwards25519_scalarmulbase_alt.o \
            curve25519/edwards25519_scalarmuldouble.o \
            curve25519/edwards25519_scalarmuldouble_alt.o \
            p256/p256_montjadd.o \
            p256/p256_montjadd_alt.o \
            p256/p256_montjdouble.o \
            p256/p256_montjdouble_alt.o \
            p256/p256_montjmixadd.o \
            p256/p256_montjmixadd_alt.o \
            p256/p256_montjscalarmul.o \
            p256/p256_montjscalarmul_alt.o \
            p256/p256_scalarmul.o \
            p256/p256_scalarmul_alt.o \
            p256/p256_scalarmulbase.o \
            p256/p256_scalarmulbase_alt.o \
            p384/p384_montjadd.o \
            p384/p384_montjadd_alt.o \
            p384/p384_montjdouble.o \
            p384/p384_montjdouble_alt.o \
            p384/p384_montjmixadd.o \
            p384/p384_montjmixadd_alt.o \
            p384/p384_montjscalarmul.o \
            p384/p384_montjscalarmul_alt.o \
            p521/p521_jadd.o \
            p521/p521_jadd_alt.o \
            p521/p521_jdouble.o \
            p521/p521_jdouble_alt.o \
            p521/p521_jmixadd.o \
            p521/p521_jmixadd_alt.o \
            p521/p521_jscalarmul.o \
            p521/p521_jscalarmul_alt.o \
            secp256k1/secp256k1_jadd.o \
            secp256k1/secp256k1_jadd_alt.o \
            secp256k1/secp256k1_jdouble.o \
            secp256k1/secp256k1_jdouble_alt.o \
            secp256k1/secp256k1_jmixadd.o \
            secp256k1/secp256k1_jmixadd_alt.o \
            sm2/sm2_montjadd.o \
            sm2/sm2_montjadd_alt.o \
            sm2/sm2_montjdouble.o \
            sm2/sm2_montjdouble_alt.o \
            sm2/sm2_montjmixadd.o \
            sm2/sm2_montjmixadd_alt.o \
            sm2/sm2_montjscalarmul.o \
            sm2/sm2_montjscalarmul_alt.o

BIGNUM_OBJ = curve25519/bignum_add_p25519.o \
             curve25519/bignum_cmul_p25519.o \
             curve25519/bignum_cmul_p25519_alt.o \
             curve25519/bignum_double_p25519.o \
             curve25519/bignum_inv_p25519.o \
             curve25519/bignum_invsqrt_p25519.o \
             curve25519/bignum_invsqrt_p25519_alt.o \
             curve25519/bignum_madd_n25519.o \
             curve25519/bignum_madd_n25519_alt.o \
             curve25519/bignum_mod_m25519_4.o \
             curve25519/bignum_mod_n25519.o \
             curve25519/bignum_mod_n25519_4.o \
             curve25519/bignum_mod_p25519_4.o \
             curve25519/bignum_mul_p25519.o \
             curve25519/bignum_mul_p25519_alt.o \
             curve25519/bignum_neg_p25519.o \
             curve25519/bignum_optneg_p25519.o \
             curve25519/bignum_sqr_p25519.o \
             curve25519/bignum_sqr_p25519_alt.o \
             curve25519/bignum_sqrt_p25519.o \
             curve25519/bignum_sqrt_p25519_alt.o \
             curve25519/bignum_sub_p25519.o \
             fastmul/bignum_emontredc_8n.o \
             fastmul/bignum_kmul_16_32.o \
             fastmul/bignum_kmul_32_64.o \
             fastmul/bignum_ksqr_16_32.o \
             fastmul/bignum_ksqr_32_64.o \
             fastmul/bignum_mul_4_8.o \
             fastmul/bignum_mul_4_8_alt.o \
             fastmul/bignum_mul_6_12.o \
             fastmul/bignum_mul_6_12_alt.o \
             fastmul/bignum_mul_8_16.o \
             fastmul/bignum_mul_8_16_alt.o \
             fastmul/bignum_sqr_4_8.o \
             fastmul/bignum_sqr_4_8_alt.o \
             fastmul/bignum_sqr_6_12.o \
             fastmul/bignum_sqr_6_12_alt.o \
             fastmul/bignum_sqr_8_16.o \
             fastmul/bignum_sqr_8_16_alt.o \
             generic/bignum_add.o \
             generic/bignum_amontifier.o \
             generic/bignum_amontmul.o \
             generic/bignum_amontredc.o \
             generic/bignum_amontsqr.o \
             generic/bignum_bitfield.o \
             generic/bignum_bitsize.o \
             generic/bignum_cdiv.o \
             generic/bignum_cdiv_exact.o \
             generic/bignum_cld.o \
             generic/bignum_clz.o \
             generic/bignum_cmadd.o \
             generic/bignum_cmnegadd.o \
             generic/bignum_cmod.o \
             generic/bignum_cmul.o \
             generic/bignum_coprime.o \
             generic/bignum_copy.o \
             generic/bignum_copy_row_from_table.o \
             generic/bignum_ctd.o \
             generic/bignum_ctz.o \
             generic/bignum_demont.o \
             generic/bignum_digit.o \
             generic/bignum_digitsize.o \
             generic/bignum_divmod10.o \
             generic/bignum_emontredc.o \
             generic/bignum_eq.o \
             generic/bignum_even.o \
             generic/bignum_ge.o \
             generic/bignum_gt.o \
             generic/bignum_iszero.o \
             generic/bignum_le.o \
             generic/bignum_lt.o \
             generic/bignum_madd.o \
             generic/bignum_modadd.o \
             generic/bignum_moddouble.o \
             generic/bignum_modexp.o \
             generic/bignum_modifier.o \
             generic/bignum_modinv.o \
             generic/bignum_modoptneg.o \
             generic/bignum_modsub.o \
             generic/bignum_montifier.o \
             generic/bignum_montmul.o \
             generic/bignum_montredc.o \
             generic/bignum_montsqr.o \
             generic/bignum_mul.o \
             generic/bignum_muladd10.o \
             generic/bignum_mux.o \
             generic/bignum_mux16.o \
             generic/bignum_negmodinv.o \
             generic/bignum_nonzero.o \
             generic/bignum_normalize.o \
             generic/bignum_odd.o \
             generic/bignum_of_word.o \
             generic/bignum_optadd.o \
             generic/bignum_optneg.o \
             generic/bignum_optsub.o \
             generic/bignum_optsubadd.o \
             generic/bignum_pow2.o \
             generic/bignum_shl_small.o \
             generic/bignum_shr_small.o \
             generic/bignum_sqr.o \
             generic/bignum_sub.o \
             generic/word_bytereverse.o \
             generic/word_clz.o \
             generic/word_ctz.o \
             generic/word_divstep59.o \
             generic/word_max.o \
             generic/word_min.o \
             generic/word_negmodinv.o \
             generic/word_popcount.o \
             generic/word_recip.o \
             p256/bignum_add_p256.o \
             p256/bignum_bigendian_4.o \
             p256/bignum_cmul_p256.o \
             p256/bignum_cmul_p256_alt.o \
             p256/bignum_deamont_p256.o \
             p256/bignum_deamont_p256_alt.o \
             p256/bignum_demont_p256.o \
             p256/bignum_demont_p256_alt.o \
             p256/bignum_double_p256.o \
             p256/bignum_half_p256.o \
             p256/bignum_inv_p256.o \
             p256/bignum_littleendian_4.o \
             p256/bignum_mod_n256.o \
             p256/bignum_mod_n256_alt.o \
             p256/bignum_mod_n256_4.o \
             p256/bignum_mod_p256.o \
             p256/bignum_mod_p256_alt.o \
             p256/bignum_mod_p256_4.o \
             p256/bignum_montinv_p256.o \
             p256/bignum_montmul_p256.o \
             p256/bignum_montmul_p256_alt.o \
             p256/bignum_montsqr_p256.o \
             p256/bignum_montsqr_p256_alt.o \
             p256/bignum_mux_4.o \
             p256/bignum_neg_p256.o \
             p256/bignum_nonzero_4.o \
             p256/bignum_optneg_p256.o \
             p256/bignum_sub_p256.o \
             p256/bignum_tomont_p256.o \
             p256/bignum_tomont_p256_alt.o \
             p256/bignum_triple_p256.o \
             p256/bignum_triple_p256_alt.o \
             p384/bignum_add_p384.o \
             p384/bignum_bigendian_6.o \
             p384/bignum_cmul_p384.o \
             p384/bignum_cmul_p384_alt.o \
             p384/bignum_deamont_p384.o \
             p384/bignum_deamont_p384_alt.o \
             p384/bignum_demont_p384.o \
             p384/bignum_demont_p384_alt.o \
             p384/bignum_double_p384.o \
             p384/bignum_half_p384.o \
             p384/bignum_inv_p384.o \
             p384/bignum_littleendian_6.o \
             p384/bignum_mod_n384.o \
             p384/bignum_mod_n384_alt.o \
             p384/bignum_mod_n384_6.o \
             p384/bignum_mod_p384.o \
             p384/bignum_mod_p384_alt.o \
             p384/bignum_mod_p384_6.o \
             p384/bignum_montinv_p384.o \
             p384/bignum_montmul_p384.o \
             p384/bignum_montmul_p384_alt.o \
             p384/bignum_montsqr_p384.o \
             p384/bignum_montsqr_p384_alt.o \
             p384/bignum_mux_6.o \
             p384/bignum_neg_p384.o \
             p384/bignum_nonzero_6.o \
             p384/bignum_optneg_p384.o \
             p384/bignum_sub_p384.o \
             p384/bignum_tomont_p384.o \
             p384/bignum_tomont_p384_alt.o \
             p384/bignum_triple_p384.o \
             p384/bignum_triple_p384_alt.o \
             p521/bignum_add_p521.o \
             p521/bignum_cmul_p521.o \
             p521/bignum_cmul_p521_alt.o \
             p521/bignum_deamont_p521.o \
             p521/bignum_demont_p521.o \
             p521/bignum_double_p521.o \
             p521/bignum_fromlebytes_p521.o \
             p521/bignum_half_p521.o \
             p521/bignum_inv_p521.o \
             p521/bignum_mod_n521_9.o \
             p521/bignum_mod_n521_9_alt.o \
             p521/bignum_mod_p521_9.o \
             p521/bignum_montmul_p521.o \
             p521/bignum_montmul_p521_alt.o \
             p521/bignum_montsqr_p521.o \
             p521/bignum_montsqr_p521_alt.o \
             p521/bignum_mul_p521.o \
             p521/bignum_mul_p521_alt.o \
             p521/bignum_neg_p521.o \
             p521/bignum_optneg_p521.o \
             p521/bignum_sqr_p521.o \
             p521/bignum_sqr_p521_alt.o \
             p521/bignum_sub_p521.o \
             p521/bignum_tolebytes_p521.o \
             p521/bignum_tomont_p521.o \
             p521/bignum_triple_p521.o \
             p521/bignum_triple_p521_alt.o \
             secp256k1/bignum_add_p256k1.o \
             secp256k1/bignum_cmul_p256k1.o \
             secp256k1/bignum_cmul_p256k1_alt.o \
             secp256k1/bignum_deamont_p256k1.o \
             secp256k1/bignum_demont_p256k1.o \
             secp256k1/bignum_double_p256k1.o \
             secp256k1/bignum_half_p256k1.o \
             secp256k1/bignum_mod_n256k1_4.o \
             secp256k1/bignum_mod_p256k1_4.o \
             secp256k1/bignum_montmul_p256k1.o \
             secp256k1/bignum_montmul_p256k1_alt.o \
             secp256k1/bignum_montsqr_p256k1.o \
             secp256k1/bignum_montsqr_p256k1_alt.o \
             secp256k1/bignum_mul_p256k1.o \
             secp256k1/bignum_mul_p256k1_alt.o \
             secp256k1/bignum_neg_p256k1.o \
             secp256k1/bignum_optneg_p256k1.o \
             secp256k1/bignum_sqr_p256k1.o \
             secp256k1/bignum_sqr_p256k1_alt.o \
             secp256k1/bignum_sub_p256k1.o \
             secp256k1/bignum_tomont_p256k1.o \
             secp256k1/bignum_tomont_p256k1_alt.o \
             secp256k1/bignum_triple_p256k1.o \
             secp256k1/bignum_triple_p256k1_alt.o \
             sm2/bignum_add_sm2.o \
             sm2/bignum_cmul_sm2.o \
             sm2/bignum_cmul_sm2_alt.o \
             sm2/bignum_deamont_sm2.o \
             sm2/bignum_demont_sm2.o \
             sm2/bignum_double_sm2.o \
             sm2/bignum_half_sm2.o \
             sm2/bignum_inv_sm2.o \
             sm2/bignum_mod_nsm2.o \
             sm2/bignum_mod_nsm2_alt.o \
             sm2/bignum_mod_nsm2_4.o \
             sm2/bignum_mod_sm2.o \
             sm2/bignum_mod_sm2_4.o \
             sm2/bignum_montinv_sm2.o \
             sm2/bignum_montmul_sm2.o \
             sm2/bignum_montmul_sm2_alt.o \
             sm2/bignum_montsqr_sm2.o \
             sm2/bignum_montsqr_sm2_alt.o \
             sm2/bignum_neg_sm2.o \
             sm2/bignum_optneg_sm2.o \
             sm2/bignum_sub_sm2.o \
             sm2/bignum_tomont_sm2.o \
             sm2/bignum_triple_sm2.o \
             sm2/bignum_triple_sm2_alt.o

OBJ = $(POINT_OBJ) $(BIGNUM_OBJ)

.PHONY: bmi clean clobber

# Actual object files for execution, with the "native" ABI

%.o : %.S ; cat $< | $(PREPROCESS) | $(SPLIT) | $(ASSEMBLE) -o $@ -

# Windows ABI variants used only for proof checking

WINOBJ  = $(OBJ:.o=.obj)

%.obj : %.S ; cat $< | $(WINPREPROCESS) | $(SPLIT) | $(ASSEMBLE) -o $@ -

libs2nbignum.a: $(OBJ) ; ar -rc libs2nbignum.a $(OBJ)

winobj: $(WINOBJ) ;

clean:; rm -f libs2nbignum.a */*.o */*.obj */*.correct

# Dynamically regenerate or destroy the files recording which functions
# use BMI and/or ADX instructions in the x86 versions. These won't run
# on some older x86 machines

yesbmi_functions: $(OBJ) ; for i in */*.o; do objdump -d $$i | (egrep -qi '(mulx|adcx|adox)' && grep 'S2N_BN_SYMBOL' `echo $$i | sed -e 's/o$$/S/'`) ; done | sed -e 's/S2N_BN_SYMBOL(//; s/)://' | sort >yesbmi_functions
nonbmi_functions: $(OBJ) ; for i in */*.o; do objdump -d $$i | (egrep -qi '(mulx|adcx|adox)' || grep 'S2N_BN_SYMBOL' `echo $$i | sed -e 's/o$$/S/'`) ; done | sed -e 's/S2N_BN_SYMBOL(//; s/)://' | sort >nonbmi_functions

bmi: yesbmi_functions nonbmi_functions ; [ `cat ???bmi_functions | sort | uniq | wc -l` -eq `grep '^extern' ../include/s2n-bignum.h | grep -v _neon | wc -l` ]

clobber: clean ; rm -f yesbmi_functions nonbmi_functions

# Proof-related parts
#
# The proof files are all independent, though each one loads the
# same common infrastructure "base.ml". So you can potentially
# run the proofs in parallel for more speed, e.g.
#
#    nohup make -j 16 proofs &
#
# On debian, the underlying prover HOL Light can be installed as a package
# by something like
#
#    sudo apt-get install hol-light
#
# for which you would set this below:
#
#    HOLDIR=/usr/share/hol-light
#
# If you build hol-light yourself (see https://github.com/jrh13/hol-light)
# in your home directory, and do "make" inside the subdirectory hol-light,
# then the following HOLDIR setting should be right:

HOLDIR?=$(HOME)/hol-light
HOLLIGHT:=$(HOLDIR)/hol.sh

PROOFS = $(OBJ:.o=.correct)

# Cases where a proof uses other proofs for lemmas and/or subroutines

curve25519/curve25519_x25519.correct: curve25519/bignum_inv_p25519.o curve25519/bignum_inv_p25519.obj proofs/curve25519_x25519.ml curve25519/curve25519_x25519.o curve25519/curve25519_x25519.obj ; ../tools/run-proof.sh x86 curve25519_x25519 "$(HOLLIGHT)" $@
curve25519/curve25519_x25519_alt.correct: curve25519/bignum_inv_p25519.o curve25519/bignum_inv_p25519.obj proofs/curve25519_x25519_alt.ml curve25519/curve25519_x25519_alt.o curve25519/curve25519_x25519_alt.obj ; ../tools/run-proof.sh x86 curve25519_x25519_alt "$(HOLLIGHT)" $@
curve25519/curve25519_x25519_byte.correct: curve25519/bignum_inv_p25519.o curve25519/bignum_inv_p25519.obj proofs/curve25519_x25519_byte.ml curve25519/curve25519_x25519_byte.o curve25519/curve25519_x25519_byte.obj ; ../tools/run-proof.sh x86 curve25519_x25519_byte "$(HOLLIGHT)" $@
curve25519/curve25519_x25519_byte_alt.correct: curve25519/bignum_inv_p25519.o curve25519/bignum_inv_p25519.obj proofs/curve25519_x25519_byte_alt.ml curve25519/curve25519_x25519_byte_alt.o curve25519/curve25519_x25519_byte_alt.obj ; ../tools/run-proof.sh x86 curve25519_x25519_byte_alt "$(HOLLIGHT)" $@
curve25519/curve25519_x25519base.correct: curve25519/bignum_inv_p25519.o curve25519/bignum_inv_p25519.obj proofs/curve25519_x25519base.ml curve25519/curve25519_x25519base.o curve25519/curve25519_x25519base.obj ; ../tools/run-proof.sh x86 curve25519_x25519base "$(HOLLIGHT)" $@
curve25519/curve25519_x25519base_alt.correct: curve25519/bignum_inv_p25519.o curve25519/bignum_inv_p25519.obj proofs/curve25519_x25519base_alt.ml curve25519/curve25519_x25519base_alt.o curve25519/curve25519_x25519base_alt.obj ; ../tools/run-proof.sh x86 curve25519_x25519base_alt "$(HOLLIGHT)" $@
curve25519/curve25519_x25519base_byte.correct: curve25519/bignum_inv_p25519.o curve25519/bignum_inv_p25519.obj proofs/curve25519_x25519base_byte.ml curve25519/curve25519_x25519base_byte.o curve25519/curve25519_x25519base_byte.obj ; ../tools/run-proof.sh x86 curve25519_x25519base_byte "$(HOLLIGHT)" $@
curve25519/curve25519_x25519base_byte_alt.correct: curve25519/bignum_inv_p25519.o curve25519/bignum_inv_p25519.obj proofs/curve25519_x25519base_byte_alt.ml curve25519/curve25519_x25519base_byte_alt.o curve25519/curve25519_x25519base_byte_alt.obj ; ../tools/run-proof.sh x86 curve25519_x25519base_byte_alt "$(HOLLIGHT)" $@
curve25519/edwards25519_scalarmulbase.correct: curve25519/bignum_inv_p25519.o curve25519/bignum_inv_p25519.obj proofs/edwards25519_scalarmulbase.ml curve25519/edwards25519_scalarmulbase.o curve25519/edwards25519_scalarmulbase.obj ; ../tools/run-proof.sh x86 edwards25519_scalarmulbase "$(HOLLIGHT)" $@
curve25519/edwards25519_scalarmulbase_alt.correct: curve25519/bignum_inv_p25519.o curve25519/bignum_inv_p25519.obj proofs/edwards25519_scalarmulbase_alt.ml curve25519/edwards25519_scalarmulbase_alt.o curve25519/edwards25519_scalarmulbase_alt.obj ; ../tools/run-proof.sh x86 edwards25519_scalarmulbase_alt "$(HOLLIGHT)" $@
curve25519/edwards25519_scalarmuldouble.correct: curve25519/bignum_inv_p25519.o curve25519/bignum_inv_p25519.obj proofs/edwards25519_scalarmuldouble.ml curve25519/edwards25519_scalarmuldouble.o curve25519/edwards25519_scalarmuldouble.obj ; ../tools/run-proof.sh x86 edwards25519_scalarmuldouble "$(HOLLIGHT)" $@
curve25519/edwards25519_scalarmuldouble_alt.correct: curve25519/bignum_inv_p25519.o curve25519/bignum_inv_p25519.obj proofs/edwards25519_scalarmuldouble_alt.ml curve25519/edwards25519_scalarmuldouble_alt.o curve25519/edwards25519_scalarmuldouble_alt.obj ; ../tools/run-proof.sh x86 edwards25519_scalarmuldouble_alt "$(HOLLIGHT)" $@
generic/bignum_modexp.correct: generic/bignum_amontifier.correct generic/bignum_amontmul.correct generic/bignum_demont.correct generic/bignum_mux.correct proofs/bignum_modexp.ml generic/bignum_modexp.o generic/bignum_modexp.obj ; ../tools/run-proof.sh x86 bignum_modexp "$(HOLLIGHT)" $@
p256/p256_montjscalarmul.correct:  proofs/p256_montjadd.ml p256/p256_montjadd.o p256/p256_montjadd.obj proofs/p256_montjdouble.ml p256/p256_montjdouble.o p256/p256_montjdouble.obj proofs/p256_montjscalarmul.ml p256/p256_montjscalarmul.o p256/p256_montjscalarmul.obj ; ../tools/run-proof.sh x86 p256_montjscalarmul "$(HOLLIGHT)" $@
p256/p256_montjscalarmul_alt.correct: proofs/p256_montjadd_alt.ml p256/p256_montjadd_alt.o p256/p256_montjadd_alt.obj proofs/p256_montjdouble_alt.ml p256/p256_montjdouble_alt.o p256/p256_montjdouble_alt.obj proofs/p256_montjscalarmul_alt.ml p256/p256_montjscalarmul_alt.o p256/p256_montjscalarmul_alt.obj ; ../tools/run-proof.sh x86 p256_montjscalarmul_alt "$(HOLLIGHT)" $@
p256/p256_scalarmul.correct: proofs/bignum_demont_p256.ml p256/bignum_demont_p256.o p256/bignum_demont_p256.obj proofs/bignum_inv_p256.ml p256/bignum_inv_p256.o p256/bignum_inv_p256.obj proofs/bignum_montmul_p256.ml p256/bignum_montmul_p256.o p256/bignum_montmul_p256.obj proofs/bignum_montsqr_p256.ml p256/bignum_montsqr_p256.o p256/bignum_montsqr_p256.obj proofs/bignum_tomont_p256.ml p256/bignum_tomont_p256.o p256/bignum_tomont_p256.obj proofs/p256_montjadd.ml p256/p256_montjadd.o p256/p256_montjadd.obj proofs/p256_montjdouble.ml p256/p256_montjdouble.o p256/p256_montjdouble.obj proofs/p256_montjmixadd.ml p256/p256_montjmixadd.o p256/p256_montjmixadd.obj proofs/p256_scalarmul.ml p256/p256_scalarmul.o p256/p256_scalarmul.obj ; ../tools/run-proof.sh x86 p256_scalarmul "$(HOLLIGHT)" $@
p256/p256_scalarmul_alt.correct: proofs/bignum_demont_p256_alt.ml p256/bignum_demont_p256_alt.o p256/bignum_demont_p256_alt.obj proofs/bignum_inv_p256.ml p256/bignum_inv_p256.o p256/bignum_inv_p256.obj proofs/bignum_montmul_p256_alt.ml p256/bignum_montmul_p256_alt.o p256/bignum_montmul_p256_alt.obj proofs/bignum_montsqr_p256_alt.ml p256/bignum_montsqr_p256_alt.o p256/bignum_montsqr_p256_alt.obj proofs/bignum_tomont_p256_alt.ml p256/bignum_tomont_p256_alt.o p256/bignum_tomont_p256_alt.obj proofs/p256_montjadd_alt.ml p256/p256_montjadd_alt.o p256/p256_montjadd_alt.obj proofs/p256_montjdouble_alt.ml p256/p256_montjdouble_alt.o p256/p256_montjdouble_alt.obj proofs/p256_montjmixadd_alt.ml p256/p256_montjmixadd_alt.o p256/p256_montjmixadd_alt.obj proofs/p256_scalarmul_alt.ml p256/p256_scalarmul_alt.o p256/p256_scalarmul_alt.obj ; ../tools/run-proof.sh x86 p256_scalarmul_alt "$(HOLLIGHT)" $@
p256/p256_scalarmulbase.correct: proofs/bignum_demont_p256.ml p256/bignum_demont_p256.o p256/bignum_demont_p256.obj proofs/bignum_inv_p256.ml p256/bignum_inv_p256.o p256/bignum_inv_p256.obj proofs/bignum_montmul_p256.ml p256/bignum_montmul_p256.o p256/bignum_montmul_p256.obj proofs/bignum_montsqr_p256.ml p256/bignum_montsqr_p256.o p256/bignum_montsqr_p256.obj proofs/p256_montjmixadd.ml p256/p256_montjmixadd.o p256/p256_montjmixadd.obj proofs/p256_scalarmulbase.ml p256/p256_scalarmulbase.o p256/p256_scalarmulbase.obj ; ../tools/run-proof.sh x86 p256_scalarmulbase "$(HOLLIGHT)" $@
p256/p256_scalarmulbase_alt.correct: proofs/bignum_demont_p256_alt.ml p256/bignum_demont_p256_alt.o p256/bignum_demont_p256_alt.obj proofs/bignum_inv_p256.ml p256/bignum_inv_p256.o p256/bignum_inv_p256.obj proofs/bignum_montmul_p256_alt.ml p256/bignum_montmul_p256_alt.o p256/bignum_montmul_p256_alt.obj proofs/bignum_montsqr_p256_alt.ml p256/bignum_montsqr_p256_alt.o p256/bignum_montsqr_p256_alt.obj  proofs/p256_montjmixadd_alt.ml p256/p256_montjmixadd_alt.o p256/p256_montjmixadd_alt.obj proofs/p256_scalarmulbase_alt.ml p256/p256_scalarmulbase_alt.o p256/p256_scalarmulbase_alt.obj ; ../tools/run-proof.sh x86 p256_scalarmulbase_alt "$(HOLLIGHT)" $@
p384/p384_montjscalarmul.correct:  proofs/p384_montjadd.ml p384/p384_montjadd.o p384/p384_montjadd.obj proofs/p384_montjdouble.ml p384/p384_montjdouble.o p384/p384_montjdouble.obj proofs/p384_montjscalarmul.ml p384/p384_montjscalarmul.o p384/p384_montjscalarmul.obj ; ../tools/run-proof.sh x86 p384_montjscalarmul "$(HOLLIGHT)" $@
p384/p384_montjscalarmul_alt.correct: proofs/p384_montjadd_alt.ml p384/p384_montjadd_alt.o p384/p384_montjadd_alt.obj proofs/p384_montjdouble_alt.ml p384/p384_montjdouble_alt.o p384/p384_montjdouble_alt.obj proofs/p384_montjscalarmul_alt.ml p384/p384_montjscalarmul_alt.o p384/p384_montjscalarmul_alt.obj ; ../tools/run-proof.sh x86 p384_montjscalarmul_alt "$(HOLLIGHT)" $@
p521/p521_jscalarmul.correct: proofs/bignum_mod_n521_9.ml p521/bignum_mod_n521_9.o p521/bignum_mod_n521_9.obj proofs/bignum_mod_p521_9.ml p521/bignum_mod_p521_9.o p521/bignum_mod_p521_9.obj proofs/p521_jscalarmul.ml p521/p521_jscalarmul.o p521/p521_jscalarmul.obj ; ../tools/run-proof.sh x86 p521_jscalarmul "$(HOLLIGHT)" $@
p521/p521_jscalarmul_alt.correct: proofs/bignum_mod_n521_9_alt.ml p521/bignum_mod_n521_9_alt.o p521/bignum_mod_n521_9_alt.obj proofs/bignum_mod_p521_9.ml p521/bignum_mod_p521_9.o p521/bignum_mod_p521_9.obj proofs/p521_jscalarmul_alt.ml p521/p521_jscalarmul_alt.o p521/p521_jscalarmul_alt.obj ; ../tools/run-proof.sh x86 p521_jscalarmul_alt "$(HOLLIGHT)" $@
sm2/sm2_montjscalarmul.correct:  proofs/sm2_montjadd.ml sm2/sm2_montjadd.o sm2/sm2_montjadd.obj proofs/sm2_montjdouble.ml sm2/sm2_montjdouble.o sm2/sm2_montjdouble.obj proofs/sm2_montjscalarmul.ml sm2/sm2_montjscalarmul.o sm2/sm2_montjscalarmul.obj ; ../tools/run-proof.sh x86 sm2_montjscalarmul "$(HOLLIGHT)" $@
sm2/sm2_montjscalarmul_alt.correct: proofs/sm2_montjadd_alt.ml sm2/sm2_montjadd_alt.o sm2/sm2_montjadd_alt.obj proofs/sm2_montjdouble_alt.ml sm2/sm2_montjdouble_alt.o sm2/sm2_montjdouble_alt.obj proofs/sm2_montjscalarmul_alt.ml sm2/sm2_montjscalarmul_alt.o sm2/sm2_montjscalarmul_alt.obj ; ../tools/run-proof.sh x86 sm2_montjscalarmul_alt "$(HOLLIGHT)" $@

# All other other instances are standalone

curve25519/%.correct: proofs/%.ml curve25519/%.o curve25519/%.obj ; ../tools/run-proof.sh x86 "$*" "$(HOLLIGHT)" $@
fastmul/%.correct: proofs/%.ml fastmul/%.o fastmul/%.obj ; ../tools/run-proof.sh x86 "$*" "$(HOLLIGHT)" $@
generic/%.correct: proofs/%.ml generic/%.o generic/%.obj ; ../tools/run-proof.sh x86 "$*" "$(HOLLIGHT)" $@
p256/%.correct: proofs/%.ml p256/%.o p256/%.obj ; ../tools/run-proof.sh x86 "$*" "$(HOLLIGHT)" $@
p384/%.correct: proofs/%.ml p384/%.o p384/%.obj ; ../tools/run-proof.sh x86 "$*" "$(HOLLIGHT)" $@
p521/%.correct: proofs/%.ml p521/%.o p521/%.obj ; ../tools/run-proof.sh x86 "$*" "$(HOLLIGHT)" $@
secp256k1/%.correct: proofs/%.ml secp256k1/%.o secp256k1/%.obj ; ../tools/run-proof.sh x86 "$*" "$(HOLLIGHT)" $@
sm2/%.correct: proofs/%.ml sm2/%.o sm2/%.obj ; ../tools/run-proof.sh x86 "$*" "$(HOLLIGHT)" $@

run_proofs: $(PROOFS);

proofs: run_proofs ; ../tools/count-proofs.sh .


x86-insns.ml: $(OBJ) $(WINOBJ); ../tools/list-x86-insns.sh x86-insns.ml
# Always run sematest regardless of dependency check
FORCE: ;
# Always use max. # of cores because in Makefile one cannot get the passed number of -j.
# A portable way of getting the number of max. cores:
# https://stackoverflow.com/a/23569003/1488216
NUM_CORES_FOR_SEMATEST = $(shell getconf _NPROCESSORS_ONLN)
sematest: x86-insns.ml FORCE; cat x86-insns.ml; ../tools/run-sematest.sh x86 $(NUM_CORES_FOR_SEMATEST) "$(HOLLIGHT)"
