#############################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License is located at
#
#  http://aws.amazon.com/apache2.0
#
# or in the "LICENSE" file accompanying this file. This file is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied. See the License for the specific language governing
# permissions and limitations under the License.
#############################################################################

# If actually on an ARM8 machine, just use the GNU assmbler (as). Otherwise
# use a cross-assembling version so that the code can still be assembled
# and the proofs checked against the object files (though you won't be able
# to run code without additional emulation infrastructure). The aarch64
# cross-assembling version can be installed manually by something like:
#
#  sudo apt-get install binutils-aarch64-linux-gnu

UNAME_RESULT=$(shell uname -p)

ifeq ($(UNAME_RESULT),aarch64)
GAS=as
else
GAS=aarch64-linux-gnu-as
endif

# List of object files

OBJ = bignum_add.o \
      bignum_amontifier.o \
      bignum_amontmul.o \
      bignum_amontredc.o \
      bignum_amontsqr.o \
      bignum_bitfield.o \
      bignum_bitsize.o \
      bignum_cld.o \
      bignum_clz.o \
      bignum_cmadd.o \
      bignum_cmul.o \
      bignum_coprime.o \
      bignum_copy.o \
      bignum_ctd.o \
      bignum_ctz.o \
      bignum_demont.o \
      bignum_digit.o \
      bignum_digitsize.o \
      bignum_emontredc.o \
      bignum_eq.o \
      bignum_even.o \
      bignum_ge.o \
      bignum_gt.o \
      bignum_iszero.o \
      bignum_le.o \
      bignum_lt.o \
      bignum_madd.o \
      bignum_modadd.o \
      bignum_moddouble.o \
      bignum_modifier.o \
      bignum_modinv.o \
      bignum_modoptneg.o \
      bignum_modsub.o \
      bignum_montifier.o \
      bignum_montmul.o \
      bignum_montredc.o \
      bignum_montsqr.o \
      bignum_mul.o \
      bignum_mux.o \
      bignum_mux16.o \
      bignum_negmodinv.o \
      bignum_nonzero.o \
      bignum_normalize.o \
      bignum_odd.o \
      bignum_of_word.o \
      bignum_optadd.o \
      bignum_optneg.o \
      bignum_optsub.o \
      bignum_optsubadd.o \
      bignum_pow2.o \
      bignum_shl_small.o \
      bignum_shr_small.o \
      bignum_sub.o \
      word_bytereverse.o \
      word_clz.o \
      word_ctz.o \
      word_negmodinv.o

%.o : %.S ; cpp $< | $(GAS) -o $@ -

default: $(OBJ);

clean:; rm -f *.o *.correct