(*
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
 *)

(* ========================================================================= *)
(* Simplified model of aarch64 (64-bit ARM) semantics.                       *)
(* ========================================================================= *)

(*** For convenience we lump the stack pointer in as general register 31.
 *** The indexing is cleaner for a 32-bit enumeration via words, and in
 *** fact in some settings this may be interpreted correctly when register 31
 *** is used in an encoding (in our setting it means the zero register).
 ***
 *** As with x86 we assume a full 64-bit address space even though in practice
 *** it is often restricted to smaller (signed) portions
 ***
 *** We just have the basic flags and ignore exception masking flags, other
 *** system level stuff (for now)
 ***)

let armstate_INDUCT,armstate_RECURSION,armstate_COMPONENTS =
  define_auto_record_type
   "armstate =
     { PC: int64;                       // One 64-bit program counter
       registers : 5 word->int64;       // 31 general-purpose registers plus SP
       simdregisters: 5 word->int128;   // 32 SIMD registers
       flags: 4 word -> bool;           // NZCV flags
       memory: 64 word -> byte          // memory
     }";;

let bytes_loaded = new_definition
 `bytes_loaded s pc l <=>
     read (memory :> bytelist(pc,LENGTH l)) s = l`;;

let bytes_loaded_nil = prove (`bytes_loaded s pc []`, REWRITE_TAC [
  bytes_loaded; READ_COMPONENT_COMPOSE; LENGTH; bytelist_clauses]);;

let bytes_loaded_append = prove
 (`bytes_loaded s pc (APPEND l1 l2) <=>
   bytes_loaded s pc l1 /\ bytes_loaded s (word_add pc (word (LENGTH l1))) l2`,
  REWRITE_TAC [bytes_loaded; READ_COMPONENT_COMPOSE; read_bytelist_append]);;

let bytes_loaded_unique = METIS [bytes_loaded]
 `!s pc l1 l2. bytes_loaded s pc l1 ==> bytes_loaded s pc l2 ==>
  LENGTH l1 = LENGTH l2 ==> l1 = l2`;;

let bytes_loaded_update = METIS [bytes_loaded]
 `!l n. LENGTH l = n ==> !s pc. bytes_loaded s pc l ==>
  !s'. read(memory :> bytelist(pc,n)) s' = read(memory :> bytelist(pc,n)) s ==>
    bytes_loaded s' pc l`;;

let bytes_loaded_of_append3 = prove
 (`!l l1 l2 l3. l = APPEND l1 (APPEND l2 l3) ==>
   !s pc. bytes_loaded s (word pc) l ==>
          bytes_loaded s (word (pc + LENGTH l1)) l2`,
  REWRITE_TAC [WORD_ADD] THEN METIS_TAC [bytes_loaded_append]);;

let aligned_bytes_loaded = new_definition
 `aligned_bytes_loaded s pc l <=>
  4 divides val pc /\ bytes_loaded s pc l`;;

let DIVIDES_4_VAL_WORD_64 = prove
 (`4 divides val (word pc:int64) <=> 4 divides pc`,
  let th1 = MATCH_MP DIVIDES_EXP_LE_IMP (ARITH_RULE `2 <= 64`) in
  let th2 = REWRITE_RULE [ARITH_RULE `2 EXP 2 = 4`] (SPEC `2` th1) in
  let th3 = MATCH_MP CONG_DIVIDES_MODULUS (CONJ
    (SPECL [`pc:num`; `2 EXP 64`] CONG_MOD) th2) in
  REWRITE_TAC [VAL_WORD; DIMINDEX_64; MATCH_MP CONG_DIVIDES th3]);;

let aligned_bytes_loaded_word = prove
 (`aligned_bytes_loaded s (word pc) l <=>
   4 divides pc /\ bytes_loaded s (word pc) l`,
  REWRITE_TAC [aligned_bytes_loaded; DIVIDES_4_VAL_WORD_64]);;

let aligned_bytes_loaded_append_left = prove
 (`aligned_bytes_loaded s pc (APPEND l1 l2) ==> aligned_bytes_loaded s pc l1`,
  REWRITE_TAC [aligned_bytes_loaded; bytes_loaded_append] THEN
  METIS_TAC []);;

let aligned_bytes_loaded_append = prove
 (`4 divides LENGTH l1 ==>
   (aligned_bytes_loaded s pc (APPEND l1 l2) <=>
    aligned_bytes_loaded s pc l1 /\
    aligned_bytes_loaded s (word_add pc (word (LENGTH l1))) l2)`,
  SPEC1_TAC `pc:int64` THEN REWRITE_TAC [FORALL_WORD; GSYM WORD_ADD;
    aligned_bytes_loaded_word; bytes_loaded_append] THEN
  METIS_TAC [DIVIDES_ADD]);;

let aligned_bytes_loaded_unique =
  METIS [aligned_bytes_loaded; bytes_loaded_unique]
  `!s pc l1 l2.
   aligned_bytes_loaded s pc l1 ==> aligned_bytes_loaded s pc l2 ==>
   LENGTH l1 = LENGTH l2 ==> l1 = l2`;;

let aligned_bytes_loaded_update =
  METIS [aligned_bytes_loaded; bytes_loaded_update]
 `!l n. LENGTH l = n ==> !s pc. aligned_bytes_loaded s pc l ==>
  !s'. read(memory :> bytelist(pc,n)) s' = read(memory :> bytelist(pc,n)) s ==>
    aligned_bytes_loaded s' pc l`;;

let aligned_bytes_loaded_of_append3 = prove
 (`!l l1 l2 l3. l = APPEND l1 (APPEND l2 l3) ==> 4 divides LENGTH l1 ==>
   !s pc. aligned_bytes_loaded s (word pc) l ==>
          aligned_bytes_loaded s (word (pc + LENGTH l1)) l2`,
  REPEAT GEN_TAC THEN DISCH_THEN SUBST1_TAC THEN REWRITE_TAC [WORD_ADD] THEN
  METIS_TAC [aligned_bytes_loaded_append; aligned_bytes_loaded_append_left]);;

(* ------------------------------------------------------------------------- *)
(* Individual flags (the numbering is arbitrary, not in the ARM spec)        *)
(* ------------------------------------------------------------------------- *)

let NF = define `NF = flags :> element(word 0)`;;

let ZF = define `ZF = flags :> element(word 1)`;;

let CF = define `CF = flags :> element(word 2)`;;

let VF = define `VF = flags :> element(word 3)`;;

add_component_alias_thms [NF; ZF; CF; VF];;

(* ------------------------------------------------------------------------- *)
(* The zero register: zero as source, ignored as destination.                *)
(* This isn't literally a state component but is naturally considered one.   *)
(* ------------------------------------------------------------------------- *)

let XZR = define `XZR:(armstate,int64)component = rvalue(word 0)`;;

let WZR = define `WZR = XZR :> bottom_32`;;

add_component_alias_thms [XZR; WZR];;

(*** We also define a generic ZR to aid in alias definitions below ***)

let ZR = define `ZR:(armstate,N word)component = rvalue(word 0)`;;

(* ------------------------------------------------------------------------- *)
(* Main integer registers, defaulting to zero register for >= 31.            *)
(* ------------------------------------------------------------------------- *)

let XREG = define
  `XREG n = if n >= 31 then XZR else registers :> element(word n)`;;

(*** To precompute the case split add the whole slew individually ***)

add_component_alias_thms
 (map (fun n -> let tm = mk_comb(`XREG`,mk_small_numeral n) in
                (GEN_REWRITE_CONV I [XREG] THENC NUM_REDUCE_CONV) tm)
      (0--31));;

let  X0 = define ` X0 = XREG  0`;;
let  X1 = define ` X1 = XREG  1`;;
let  X2 = define ` X2 = XREG  2`;;
let  X3 = define ` X3 = XREG  3`;;
let  X4 = define ` X4 = XREG  4`;;
let  X5 = define ` X5 = XREG  5`;;
let  X6 = define ` X6 = XREG  6`;;
let  X7 = define ` X7 = XREG  7`;;
let  X8 = define ` X8 = XREG  8`;;
let  X9 = define ` X9 = XREG  9`;;
let X10 = define `X10 = XREG 10`;;
let X11 = define `X11 = XREG 11`;;
let X12 = define `X12 = XREG 12`;;
let X13 = define `X13 = XREG 13`;;
let X14 = define `X14 = XREG 14`;;
let X15 = define `X15 = XREG 15`;;
let X16 = define `X16 = XREG 16`;;
let X17 = define `X17 = XREG 17`;;
let X18 = define `X18 = XREG 18`;;
let X19 = define `X19 = XREG 19`;;
let X20 = define `X20 = XREG 20`;;
let X21 = define `X21 = XREG 21`;;
let X22 = define `X22 = XREG 22`;;
let X23 = define `X23 = XREG 23`;;
let X24 = define `X24 = XREG 24`;;
let X25 = define `X25 = XREG 25`;;
let X26 = define `X26 = XREG 26`;;
let X27 = define `X27 = XREG 27`;;
let X28 = define `X28 = XREG 28`;;
let X29 = define `X29 = XREG 29`;;
let X30 = define `X30 = XREG 30`;;

add_component_alias_thms
 [ X0;  X1;  X2;  X3;  X4;  X5;  X6;  X7;
   X8;  X9; X10; X11; X12; X13; X14; X15;
  X16; X17; X18; X19; X20; X21; X22; X23;
  X24; X25; X26; X27; X28; X29; X30];;

(* ------------------------------------------------------------------------- *)
(* Stack pointer.                                                            *)
(* ------------------------------------------------------------------------- *)

let SP = define `SP = registers :> element (word 31)`;;

add_component_alias_thms [SP];;

(* ------------------------------------------------------------------------- *)
(* 32-bit versions of the main integer registers. NB! As lvalues all these   *)
(* zero the top 32 bits, which matches the usual 64-bit mode behavior.       *)
(* To get pure alternatives use "bottom_32" instead of "zerotop_32".         *)
(* ------------------------------------------------------------------------- *)

let WREG = define `WREG n = XREG n :> zerotop_32`;;

let WSP = define `WSP = SP :> zerotop_32`;;

add_component_alias_thms [WREG; WSP];;

let  W0 = define ` W0 = WREG  0`;;
let  W1 = define ` W1 = WREG  1`;;
let  W2 = define ` W2 = WREG  2`;;
let  W3 = define ` W3 = WREG  3`;;
let  W4 = define ` W4 = WREG  4`;;
let  W5 = define ` W5 = WREG  5`;;
let  W6 = define ` W6 = WREG  6`;;
let  W7 = define ` W7 = WREG  7`;;
let  W8 = define ` W8 = WREG  8`;;
let  W9 = define ` W9 = WREG  9`;;
let W10 = define `W10 = WREG 10`;;
let W11 = define `W11 = WREG 11`;;
let W12 = define `W12 = WREG 12`;;
let W13 = define `W13 = WREG 13`;;
let W14 = define `W14 = WREG 14`;;
let W15 = define `W15 = WREG 15`;;
let W16 = define `W16 = WREG 16`;;
let W17 = define `W17 = WREG 17`;;
let W18 = define `W18 = WREG 18`;;
let W19 = define `W19 = WREG 19`;;
let W20 = define `W20 = WREG 20`;;
let W21 = define `W21 = WREG 21`;;
let W22 = define `W22 = WREG 22`;;
let W23 = define `W23 = WREG 23`;;
let W24 = define `W24 = WREG 24`;;
let W25 = define `W25 = WREG 25`;;
let W26 = define `W26 = WREG 26`;;
let W27 = define `W27 = WREG 27`;;
let W28 = define `W28 = WREG 28`;;
let W29 = define `W29 = WREG 29`;;
let W30 = define `W30 = WREG 30`;;

add_component_alias_thms
 [ W0;  W1;  W2;  W3;  W4;  W5;  W6;  W7;
   W8;  W9; W10; W11; W12; W13; W14; W15;
  W16; W17; W18; W19; W20; W21; W22; W23;
  W24; W25; W26; W27; W28; W29; W30];;

(* ------------------------------------------------------------------------- *)
(* The main SIMD register parts                                              *)
(* ------------------------------------------------------------------------- *)

let QREG = define `QREG n = simdregisters :> element(word n)`;;

let DREG = define `DREG n = QREG n :> bottom_64`;;

let SREG = define `SREG n = DREG n :> bottom_32`;;

let HREG = define `HREG n = SREG n :> bottom_16`;;

let BREG = define `BREG n = HREG n :> bottom_8`;;

add_component_alias_thms [QREG; DREG; SREG; HREG; BREG];;

let  Q0 = define ` Q0 = QREG  0`;;
let  Q1 = define ` Q1 = QREG  1`;;
let  Q2 = define ` Q2 = QREG  2`;;
let  Q3 = define ` Q3 = QREG  3`;;
let  Q4 = define ` Q4 = QREG  4`;;
let  Q5 = define ` Q5 = QREG  5`;;
let  Q6 = define ` Q6 = QREG  6`;;
let  Q7 = define ` Q7 = QREG  7`;;
let  Q8 = define ` Q8 = QREG  8`;;
let  Q9 = define ` Q9 = QREG  9`;;
let Q10 = define `Q10 = QREG 10`;;
let Q11 = define `Q11 = QREG 11`;;
let Q12 = define `Q12 = QREG 12`;;
let Q13 = define `Q13 = QREG 13`;;
let Q14 = define `Q14 = QREG 14`;;
let Q15 = define `Q15 = QREG 15`;;
let Q16 = define `Q16 = QREG 16`;;
let Q17 = define `Q17 = QREG 17`;;
let Q18 = define `Q18 = QREG 18`;;
let Q19 = define `Q19 = QREG 19`;;
let Q20 = define `Q20 = QREG 20`;;
let Q21 = define `Q21 = QREG 21`;;
let Q22 = define `Q22 = QREG 22`;;
let Q23 = define `Q23 = QREG 23`;;
let Q24 = define `Q24 = QREG 24`;;
let Q25 = define `Q25 = QREG 25`;;
let Q26 = define `Q26 = QREG 26`;;
let Q27 = define `Q27 = QREG 27`;;
let Q28 = define `Q28 = QREG 28`;;
let Q29 = define `Q29 = QREG 29`;;
let Q30 = define `Q30 = QREG 30`;;
let Q31 = define `Q31 = QREG 31`;;

add_component_alias_thms
 [ Q0;  Q1;  Q2;  Q3;  Q4;  Q5;  Q6;  Q7;
   Q8;  Q9; Q10; Q11; Q12; Q13; Q14; Q15;
  Q16; Q17; Q18; Q19; Q20; Q21; Q22; Q23;
  Q24; Q25; Q26; Q27; Q28; Q29; Q30; Q31];;

(* ------------------------------------------------------------------------- *)
(* The zero registers are all basically what we expect                       *)
(* ------------------------------------------------------------------------- *)

let ARM_ZERO_REGISTER = prove
 (`ZR = rvalue(word 0) /\
   XZR = rvalue(word 0) /\
   XREG 31 = rvalue(word 0) /\
   WZR = rvalue(word 0) /\
   WREG 31 = rvalue(word 0)`,
  REWRITE_TAC[XZR; WZR; XREG; WREG; GE; LE_REFL; COMPONENT_COMPOSE_RVALUE] THEN
  REWRITE_TAC[ZR] THEN CONJ_TAC THEN AP_TERM_TAC THEN
  REWRITE_TAC[FUN_EQ_THM; bottom_32; bottomhalf; READ_SUBWORD_0] THEN
  REWRITE_TAC[zerotop_32; read; through; WORD_ZX_0]);;

let XZR_ZR = prove
 (`XZR = ZR`,
  REWRITE_TAC[ARM_ZERO_REGISTER; ZR]);;

let WZR_ZR = prove
 (`WZR = ZR`,
  REWRITE_TAC[ARM_ZERO_REGISTER; ZR]);;

(*** We use ZR in some aliases but we only want these two cases ***)

add_component_alias_thms [GSYM XZR_ZR; GSYM WZR_ZR];;

(* ------------------------------------------------------------------------- *)
(* Condition codes via 4-bit encoding (ARM reference manual C.1.2.4)         *)
(* ------------------------------------------------------------------------- *)

let condition_INDUCT,condition_RECURSION = define_type
 "condition = Condition (4 word)";;

let Condition_EQ = define `Condition_EQ = Condition(word 0b0000)`;;
let Condition_NE = define `Condition_NE = Condition(word 0b0001)`;;
let Condition_CS = define `Condition_CS = Condition(word 0b0010)`;;
let Condition_HS = define `Condition_HS = Condition(word 0b0010)`;;
let Condition_CC = define `Condition_CC = Condition(word 0b0011)`;;
let Condition_LO = define `Condition_LO = Condition(word 0b0011)`;;
let Condition_MI = define `Condition_MI = Condition(word 0b0100)`;;
let Condition_PL = define `Condition_PL = Condition(word 0b0101)`;;
let Condition_VS = define `Condition_VS = Condition(word 0b0110)`;;
let Condition_VC = define `Condition_VC = Condition(word 0b0111)`;;
let Condition_HI = define `Condition_HI = Condition(word 0b1000)`;;
let Condition_LS = define `Condition_LS = Condition(word 0b1001)`;;
let Condition_GE = define `Condition_GE = Condition(word 0b1010)`;;
let Condition_LT = define `Condition_LT = Condition(word 0b1011)`;;
let Condition_GT = define `Condition_GT = Condition(word 0b1100)`;;
let Condition_LE = define `Condition_LE = Condition(word 0b1101)`;;
let Condition_AL = define `Condition_AL = Condition(word 0b1110)`;;
let Condition_NV = define `Condition_NV = Condition(word 0b1111)`;;

let CONDITION_CLAUSES =
  [Condition_EQ; Condition_NE; Condition_CS; Condition_HS;
   Condition_CC; Condition_LO; Condition_MI; Condition_PL;
   Condition_VS; Condition_VC; Condition_HI; Condition_LS;
   Condition_GE; Condition_LT; Condition_GT; Condition_LE;
   Condition_AL; Condition_NV];;

(* ------------------------------------------------------------------------- *)
(* Semantics of conditions. Note that NV = AL! (see C.1.2.4).                *)
(* We can't yet define functions by pattern-matching over words, so we need  *)
(* to justify the definition we want via an uglier unpacking.                *)
(* ------------------------------------------------------------------------- *)

let condition_semantics =
  let th = prove
   (`?f. (!s. f Condition_EQ s <=> read ZF s) /\
         (!s. f Condition_NE s <=> ~read ZF s) /\
         (!s. f Condition_CS s <=> read CF s) /\
         (!s. f Condition_HS s <=> read CF s) /\
         (!s. f Condition_CC s <=> ~read CF s) /\
         (!s. f Condition_LO s <=> ~read CF s) /\
         (!s. f Condition_MI s <=> read NF s) /\
         (!s. f Condition_PL s <=> ~read NF s) /\
         (!s. f Condition_VS s <=> read VF s) /\
         (!s. f Condition_VC s <=> ~read VF s) /\
         (!s. f Condition_HI s <=> read CF s /\ ~read ZF s) /\
         (!s. f Condition_LS s <=> ~(read CF s /\ ~read ZF s)) /\
         (!s. f Condition_GE s <=> (read NF s <=> read VF s)) /\
         (!s. f Condition_LT s <=> ~(read NF s <=> read VF s)) /\
         (!s. f Condition_GT s <=> ~read ZF s /\ (read NF s <=> read VF s)) /\
         (!s. f Condition_LE s <=>
                ~(~read ZF s /\ (read NF s <=> read VF s))) /\
         (!s. f Condition_AL s <=> T) /\
         (!s. f Condition_NV s <=> T)`,
    ONCE_REWRITE_TAC[GSYM FUN_EQ_THM] THEN REWRITE_TAC[ETA_AX] THEN
    W(MP_TAC o DISCH_ALL o instantiate_casewise_recursion o snd) THEN
    REWRITE_TAC[IMP_IMP] THEN DISCH_THEN MATCH_MP_TAC THEN
    REWRITE_TAC CONDITION_CLAUSES THEN
    REWRITE_TAC[injectivity "condition"; WORD_EQ; CONG] THEN
    CONV_TAC(ONCE_DEPTH_CONV DIMINDEX_CONV) THEN CONV_TAC NUM_REDUCE_CONV THEN
    REWRITE_TAC[SUPERADMISSIBLE_CONST] THEN
    EXISTS_TAC `\(x:condition) (y:condition). F` THEN
    REWRITE_TAC[WF_FALSE]) in
  new_specification ["condition_semantics"] th;;

(* ------------------------------------------------------------------------- *)
(* Inversion of conditions (used in aliases like CSET and CSETM)             *)
(* ------------------------------------------------------------------------- *)

let invert_condition =
 let th = prove
   (`?f. f Condition_EQ = Condition_NE /\
         f Condition_NE = Condition_EQ /\
         f Condition_CS = Condition_CC /\
         f Condition_HS = Condition_LO /\
         f Condition_CC = Condition_CS /\
         f Condition_LO = Condition_HS /\
         f Condition_MI = Condition_PL /\
         f Condition_PL = Condition_MI /\
         f Condition_VS = Condition_VC /\
         f Condition_VC = Condition_VS /\
         f Condition_HI = Condition_LS /\
         f Condition_LS = Condition_HI /\
         f Condition_GE = Condition_LT /\
         f Condition_LT = Condition_GE /\
         f Condition_GT = Condition_LE /\
         f Condition_LE = Condition_GT /\
         f Condition_AL = Condition_NV /\
         f Condition_NV = Condition_AL`,
    W(MP_TAC o DISCH_ALL o instantiate_casewise_recursion o snd) THEN
    REWRITE_TAC[IMP_IMP] THEN DISCH_THEN MATCH_MP_TAC THEN
    REWRITE_TAC CONDITION_CLAUSES THEN
    REWRITE_TAC[injectivity "condition"; WORD_EQ; CONG] THEN
    CONV_TAC(ONCE_DEPTH_CONV DIMINDEX_CONV) THEN CONV_TAC NUM_REDUCE_CONV THEN
    REWRITE_TAC[SUPERADMISSIBLE_CONST] THEN
    EXISTS_TAC `\(x:condition) (y:condition). F` THEN
    REWRITE_TAC[WF_FALSE]) in
  new_specification ["invert_condition"] th;;

let INVERT_CONDITION = prove
 (`!w. invert_condition(Condition w) = Condition(word_xor w (word 1))`,
  ONCE_REWRITE_TAC[FORALL_VAL_GEN] THEN
  REWRITE_TAC[DIMINDEX_4] THEN CONV_TAC NUM_REDUCE_CONV THEN
  CONV_TAC EXPAND_CASES_CONV THEN
  CONV_TAC WORD_REDUCE_CONV THEN
  REWRITE_TAC[REWRITE_RULE CONDITION_CLAUSES invert_condition]);;

let INVERT_CONDITION_TWICE = prove
 (`!cc. invert_condition(invert_condition cc) = cc`,
  MATCH_MP_TAC condition_INDUCT THEN REWRITE_TAC[INVERT_CONDITION;
    WORD_BITWISE_RULE `word_xor (word_xor a b) b = a`]);;

(*** Because of the special treatment of NV this is a bit ugly ***)
(*** But that is made quite explicit in the ARM documentation  ***)
(*** See "ConditionHolds" pseudocode with just this case split ***)
(*** There might be an argument for not defining Condition_NV  ***)

let CONDITION_SEMANTICS_INVERT_CONDITION = prove
 (`!cc s. condition_semantics (invert_condition cc) s =
                if cc = Condition_AL \/ cc = Condition_NV
                then condition_semantics cc s
                else ~(condition_semantics cc s)`,
  GEN_REWRITE_TAC I [SWAP_FORALL_THM] THEN GEN_TAC THEN
  MATCH_MP_TAC condition_INDUCT THEN
  ONCE_REWRITE_TAC[FORALL_VAL_GEN] THEN
  REWRITE_TAC[DIMINDEX_4] THEN CONV_TAC NUM_REDUCE_CONV THEN
  CONV_TAC EXPAND_CASES_CONV THEN
  REWRITE_TAC[REWRITE_RULE CONDITION_CLAUSES invert_condition] THEN
  REWRITE_TAC[REWRITE_RULE CONDITION_CLAUSES condition_semantics] THEN
  REWRITE_TAC(injectivity "condition" :: CONDITION_CLAUSES) THEN
  CONV_TAC WORD_REDUCE_CONV);;

(* ------------------------------------------------------------------------- *)
(* Addressing modes and offsets for loads and stores (LDP, LDR, STP, STR)    *)
(* ------------------------------------------------------------------------- *)

(*** We don't support quite all the addressing modes in C1.3.3.
 *** In particular we ignore extended 32-bit registers, which we'll never use
 *** We also ignore the post-indexed register offset, which is only in SIMD
 *** mode.
 ***
 *** We have a numeric parameter in the Shiftreg_Offset but it's only
 *** allowed to be log_2(transfer_size), i.e. usually 3. We also just treat all
 *** immediates as 64-bit without worrying about the actual limits.
 ***)

let offset_INDUCT,offset_RECURSION = define_type
 "offset =
    Register_Offset ((armstate,int64)component)      // [base, reg]
  | Shiftreg_Offset ((armstate,int64)component) num  // [base, reg, LSL k]
  | Immediate_Offset (64 word)                       // [base, #n] or [base]
  | Preimmediate_Offset (64 word)                    // [base, #n]!
  | Postimmediate_Offset (64 word)                   // [base], #n
 ";;

let no_offset = define `No_Offset = Immediate_Offset (word 0)`;;

(*** This defines the actual address offset used, so 0 for post-index ***)

let offset_address = define
 `offset_address (Register_Offset r) s = read r s /\
  offset_address (Shiftreg_Offset r k) s = word_shl (read r s) k /\
  offset_address (Immediate_Offset w) s = w /\
  offset_address (Preimmediate_Offset w) s = w /\
  offset_address (Postimmediate_Offset w) s = word 0`;;

(*** This one defines the offset to add to the register ***)

let offset_writeback = define
 `offset_writeback (Register_Offset r) = word 0 /\
  offset_writeback (Shiftreg_Offset r k) = word 0 /\
  offset_writeback (Immediate_Offset w) = word 0 /\
  offset_writeback (Preimmediate_Offset w) = w /\
  offset_writeback (Postimmediate_Offset w) = w`;;

let offset_writesback = define
 `(offset_writesback (Register_Offset r) <=> F) /\
  (offset_writesback (Shiftreg_Offset r k) <=> F) /\
  (offset_writesback (Immediate_Offset w) <=> F) /\
  (offset_writesback (Preimmediate_Offset w) <=> T) /\
  (offset_writesback (Postimmediate_Offset w) <=> T)`;;

(* ------------------------------------------------------------------------- *)
(* ABI things.                                                               *)
(* infocenter.arm.com/help/topic/com.arm.doc.ihi0055b/IHI0055B_aapcs64.pdf   *)
(* "A subroutine invocation must preserve r19-r29 and SP. In all versions of *)
(* the procedure call standard r16, r17, r29 and r30 have special roles".    *)
(* There's also some stuff implying one should avoid r18. I'm conservative   *)
(* in this and just  treat all >= 18 as to be preserved and throw in SP too  *)
(* even though it's not "really" a general-purpose register.                 *)
(* ------------------------------------------------------------------------- *)

let C_ARGUMENTS = define
 `(C_ARGUMENTS [a0;a1;a2;a3;a4;a5;a6;a7] s <=>
        read X0 s = a0 /\ read X1 s = a1 /\
        read X2 s = a2 /\ read X3 s = a3 /\
        read X4 s = a4 /\ read X5 s = a5 /\
        read X6 s = a6 /\ read X7 s = a7) /\
  (C_ARGUMENTS [a0;a1;a2;a3;a4;a5;a6] s <=>
        read X0 s = a0 /\ read X1 s = a1 /\
        read X2 s = a2 /\ read X3 s = a3 /\
        read X4 s = a4 /\ read X5 s = a5 /\
        read X6 s = a6) /\
  (C_ARGUMENTS [a0;a1;a2;a3;a4;a5] s <=>
        read X0 s = a0 /\ read X1 s = a1 /\
        read X2 s = a2 /\ read X3 s = a3 /\
        read X4 s = a4 /\ read X5 s = a5) /\
  (C_ARGUMENTS [a0;a1;a2;a3;a4] s <=>
        read X0 s = a0 /\ read X1 s = a1 /\
        read X2 s = a2 /\ read X3 s = a3 /\
        read X4 s = a4) /\
  (C_ARGUMENTS [a0;a1;a2;a3] s <=>
        read X0 s = a0 /\ read X1 s = a1 /\
        read X2 s = a2 /\ read X3 s = a3) /\
  (C_ARGUMENTS [a0;a1;a2] s <=>
        read X0 s = a0 /\ read X1 s = a1 /\
        read X2 s = a2) /\
  (C_ARGUMENTS [a0;a1] s <=>
        read X0 s = a0 /\ read X1 s = a1) /\
  (C_ARGUMENTS [a0] s <=>
        read X0 s = a0) /\
  (C_ARGUMENTS [] s <=>
        T)`;;

let C_RETURN = define
 `C_RETURN = read X0`;;

let PRESERVED_GPRS = define
 `PRESERVED_GPRS =
    [X18; X19; X20; X21; X22; X23; X24;
     X25; X26; X27; X28; X29; X30; SP]`;;

let MODIFIABLE_GPRS = define
 `MODIFIABLE_GPRS =
    [ X0;  X1;  X2;  X3;  X4;  X5;  X6;  X7;  X8;
      X9; X10; X11; X12; X13; X14; X15; X16; X17]`;;

(* ------------------------------------------------------------------------- *)
(* General register-register instructions.                                   *)
(* ------------------------------------------------------------------------- *)

let arm_ADC = define
 `arm_ADC Rd Rm Rn =
    \s. let m = read Rm s
        and n = read Rn s
        and c = bitval(read CF s) in
        let d = word_add (word_add m n) (word c) in
        (Rd := d) s`;;

let arm_ADCS = define
 `arm_ADCS Rd Rm Rn =
    \s. let m = read Rm s
        and n = read Rn s
        and c = bitval(read CF s) in
        let d = word_add (word_add m n) (word c) in
        (Rd := d ,,
         NF := (ival d < &0) ,,
         ZF := (val d = 0) ,,
         CF := ~(val m + val n + c = val d) ,,
         VF := ~(ival m + ival n + &c = ival d)) s`;;

let arm_ADD = define
 `arm_ADD Rd Rm Rn =
    \s. let m = read Rm s
        and n = read Rn s in
        let d = word_add m n in
        (Rd := d) s`;;

let arm_ADDS = define
 `arm_ADDS Rd Rm Rn =
    \s. let m = read Rm s
        and n = read Rn s in
        let d = word_add m n in
        (Rd := d ,,
         NF := (ival d < &0) ,,
         ZF := (val d = 0) ,,
         CF := ~(val m + val n = val d) ,,
         VF := ~(ival m + ival n = ival d)) s`;;

let arm_AND = define
 `arm_AND Rd Rm Rn =
    \s. let m = read Rm s
        and n = read Rn s in
        let d = word_and m n in
        (Rd := d) s`;;

let arm_ANDS = define
 `arm_ANDS Rd Rm Rn =
    \s. let m = read Rm s
        and n = read Rn s in
        let d = word_and m n in
        (Rd := d ,,
         NF := (ival d < &0) ,,
         ZF := (val d = 0) ,,
         CF := F ,,
         VF := F) s`;;

(*** For unconditional branch the offset is encoded as a 26-bit word   ***)
(*** This is turned into a 28-bit word when multiplied by 4, then sx   ***)
(*** Note that this is a longer immediate than in conditional branches ***)

let arm_B = define
 `arm_B (off:28 word) =
    \s. (PC := word_add (word_sub (read PC s) (word 4)) (word_sx off)) s`;;

(*** As with x86, we have relative and absolute versions of branch & link ***)
(*** The absolute one gives a natural way of handling linker-insertions.  ***)

let arm_BL = define
 `arm_BL (off:28 word) =
    \s. let pc = read PC s in
        (X30 := pc ,,
         PC := word_add (word_sub pc (word 4)) (word_sx off)) s`;;

let arm_BL_ABSOLUTE = define
 `arm_BL_ABSOLUTE (target:64 word) =
    \s. let pc = read PC s in
        (X30 := pc ,,
         PC := target) s`;;

(*** For conditional branches, including CBZ and CBNZ the offset is       ***)
(*** encoded as a 19-bit word that's turned into a 21-bit word multiplied ***)
(*** by 4 then sign-extended.                                             ***)

let arm_Bcond = define
 `arm_Bcond cc (off:21 word) =
        \s. (PC := if condition_semantics cc s
                   then word_add (word_sub (read PC s) (word 4)) (word_sx off)
                   else read PC s) s`;;

let arm_CBNZ = define
 `arm_CBNZ Rt (off:21 word) =
        \s. (PC := if ~(read Rt s = word 0)
                   then word_add (word_sub (read PC s) (word 4)) (word_sx off)
                   else read PC s) s`;;

let arm_CBZ = define
 `arm_CBZ Rt (off:21 word) =
        \s. (PC := if read Rt s = word 0
                   then word_add (word_sub (read PC s) (word 4)) (word_sx off)
                   else read PC s) s`;;

let arm_CLZ = define
 `arm_CLZ Rd Rn =
        \s. (Rd := (word(word_clz (read Rn s:N word)):N word)) s`;;

let arm_CSEL = define
 `arm_CSEL Rd Rn Rm cc =
        \s. (Rd := if condition_semantics cc s
                   then read Rn s
                   else read Rm s) s`;;

let arm_CSINC = define
 `arm_CSINC Rd Rn Rm cc =
        \s. (Rd := if condition_semantics cc s
                   then read Rn s
                   else word_add (read Rm s) (word 1)) s`;;

let arm_CSINV = define
 `arm_CSINV Rd Rn Rm cc =
        \s. (Rd := if condition_semantics cc s
                   then read Rn s
                   else word_not(read Rm s)) s`;;

let arm_CSNEG = define
 `arm_CSNEG Rd Rn Rm cc =
        \s. (Rd := if condition_semantics cc s
                   then read Rn s
                   else word_neg(read Rm s)) s`;;

let arm_EON = define
 `arm_EON Rd Rm Rn =
    \s. let m = read Rm s
        and n = read Rn s in
        let d = word_xor m (word_not n) in
        (Rd := d) s`;;

let arm_EOR = define
 `arm_EOR Rd Rm Rn =
    \s. let m = read Rm s
        and n = read Rn s in
        let d = word_xor m n in
        (Rd := d) s`;;

(*** We force the shift count to be of the same word type; in practice
 *** it would be fine to use 6-bit immediates for 64-bit main values,
 *** which is all we currently use
 ***)

let arm_EXTR = define
 `arm_EXTR Rd Rn Rm lsb =
    \s. let n:N word = read Rn s
        and m:N word = read Rm s
        and l = val(read lsb s:N word) MOD dimindex(:N) in
        let concat:(N tybit0)word = word_join n m in
        let d:N word = word_subword concat (l,dimindex(:N)) in
        (Rd := d) s`;;

(*** Note that the shift behaviours in the LSLV and LSRV docs
 *** exactly match the word_jshl and word_jushr with a masking;
 *** the English text about "remainder on dividing" is ambiguous
 *** but it's quite explicitly treated as unsigned in pseudocode
 ***)

let arm_LSLV = define
 `arm_LSLV Rd Rm Rn =
    \s. let m = read Rm s
        and n = read Rn s in
        let d = word_jshl m n in
        (Rd := d) s`;;

let arm_LSRV = define
 `arm_LSRV Rd Rm Rn =
    \s. let m = read Rm s
        and n = read Rn s in
        let d = word_jushr m n in
        (Rd := d) s`;;

let arm_MADD = define
 `arm_MADD Rd Rn Rm Ra =
    \s. let n:N word = read Rn s
        and m:N word = read Rm s
        and a:N word = read Ra s in
        let d:N word = word(val a + val n * val m) in
        (Rd := d) s`;;

let arm_MOVK = define
 `arm_MOVK (Rd:(armstate,N word)component) (imm:int16) pos =
    Rd :> subword(pos,16) := imm`;;

let arm_MOVN = define
 `arm_MOVN (Rd:(armstate,N word)component) (imm:int16) pos =
    Rd := word_not (word (val imm * 2 EXP pos))`;;

let arm_MOVZ = define
 `arm_MOVZ (Rd:(armstate,N word)component) (imm:int16) pos =
    Rd := word (val imm * 2 EXP pos)`;;

let arm_MSUB = define
 `arm_MSUB Rd Rn Rm Ra =
    \s. let n:N word = read Rn s
        and m:N word = read Rm s
        and a:N word = read Ra s in
        let d:N word = iword(ival a - ival n * ival m) in
        (Rd := d) s`;;

let arm_ORN = define
 `arm_ORN Rd Rm Rn =
    \s. let m = read Rm s
        and n = read Rn s in
        let d = word_or m (word_not n) in
        (Rd := d) s`;;

let arm_ORR = define
 `arm_ORR Rd Rm Rn =
    \s. let m = read Rm s
        and n = read Rn s in
        let d = word_or m n in
        (Rd := d) s`;;

(*** The default RET uses X30. ***)

let arm_RET = define
 `arm_RET Rn =
    \s. (PC := read Rn s) s`;;

(*** Note that the carry flag is inverted for subtractions ***)
(*** Flag set means no borrow, flag clear means borrow.    ***)
(*** The (signed) overflow flag is as usual.               ***)

let arm_SBC = define
 `arm_SBC Rd Rm Rn =
    \s. let m = read Rm s
        and n = read Rn s
        and c = bitval(~read CF s) in
        let d = word_sub m (word_add n (word c)) in
        (Rd := d) s`;;

let arm_SBCS = define
 `arm_SBCS Rd Rm Rn =
    \s. let m = read Rm s
        and n = read Rn s
        and c = bitval(~read CF s) in
        let d = word_sub m (word_add n (word c)) in
        (Rd := d ,,
         NF := (ival d < &0) ,,
         ZF := (val d = 0) ,,
         CF := (&(val m) - (&(val n) + &c):int = &(val d)) ,,
         VF := ~(ival m - (ival n + &c) = ival d)) s`;;

let arm_SUB = define
 `arm_SUB Rd Rm Rn =
    \s. let m = read Rm s
        and n = read Rn s in
        let d = word_sub m n in
        (Rd := d) s`;;

let arm_SUBS = define
 `arm_SUBS Rd Rm Rn =
    \s. let m = read Rm s
        and n = read Rn s in
        let d = word_sub m n in
        (Rd := d ,,
         NF := (ival d < &0) ,,
         ZF := (val d = 0) ,,
         CF := (&(val m) - &(val n):int = &(val d)) ,,
         VF := ~(ival m - ival n = ival d)) s`;;

let arm_UMULH = define
 `arm_UMULH Rd Rn Rm =
    \s. let n:N word = read Rn (s:armstate)
        and m:N word = read Rm s in
        let d:N word = word((val n * val m) DIV (2 EXP dimindex(:N))) in
        (Rd := d) s`;;

(* ------------------------------------------------------------------------- *)
(* Load and store instructions.                                              *)
(* ------------------------------------------------------------------------- *)

(*** The use of SP as a base register is special-cased because
 *** according to the architecture "when the base register is SP
 *** the stack pointer is required to be quadword (16 byte, 128 bit)
 *** aligned prior to the address calculation and write-backs ---
 *** misalignment will cause a stack alignment fault". As usual we
 *** model the "fault" with a completely undefined end state. Note
 *** that this restriction is different from 32-bit ARM: the register
 *** SP itself may for us be unaligned when not used in addressing.
 ***
 *** In the case where there is a writeback to the register being
 *** loaded/stored, the manual actually gives a more precise ramification
 *** of the undefined behavior, but we assume a worst-case completely
 *** undefined state. I am not sure if a pre/post of zero is encodable
 *** but I consider even that as a writeback.
 ***)

let arm_LDR = define
 `arm_LDR (Rt:(armstate,N word)component) Rn off =
    \s. let base = read Rn s in
        let addr = word_add base (offset_address off s) in
        (if (Rn = SP ==> aligned 16 base) /\
            (offset_writesback off ==> orthogonal_components Rt Rn)
         then
           Rt := read (memory :> wbytes addr) s ,,
           (if offset_writesback off
            then Rn := word_add base (offset_writeback off)
            else (=))
         else ASSIGNS entirety) s`;;

let arm_STR = define
 `arm_STR (Rt:(armstate,N word)component) Rn off =
    \s. let base = read Rn s in
        let addr = word_add base (offset_address off s) in
        (if (Rn = SP ==> aligned 16 base) /\
            (offset_writesback off ==> orthogonal_components Rt Rn)
         then
           memory :> wbytes addr := read Rt s ,,
           (if offset_writesback off
            then Rn := word_add base (offset_writeback off)
            else (=))
         else ASSIGNS entirety) s`;;

(*** the actually encodable offsets are a bit more limited for LDP ***)
(*** But this is all ignored at the present level and left to decoder ***)

let arm_LDP = define
 `arm_LDP (Rt1:(armstate,N word)component)
          (Rt2:(armstate,N word)component) Rn off =
    \s. let base = read Rn s in
        let addr = word_add base (offset_address off s) in
        (if (Rn = SP ==> aligned 16 base) /\
            orthogonal_components Rt1 Rt2 /\
            (offset_writesback off
             ==> orthogonal_components Rt1 Rn /\ orthogonal_components Rt2 Rn)
         then
           let w = dimindex(:N) DIV 8 in
           Rt1 := read (memory :> wbytes addr) s ,,
           Rt2 := read (memory :> wbytes(word_add addr (word w))) s ,,
           (if offset_writesback off
            then Rn := word_add base (offset_writeback off)
            else (=))
         else ASSIGNS entirety) s`;;

let arm_STP = define
 `arm_STP (Rt1:(armstate,N word)component)
          (Rt2:(armstate,N word)component) Rn off =
    \s. let base = read Rn s in
        let addr = word_add base (offset_address off s) in
        (if (Rn = SP ==> aligned 16 base) /\
            orthogonal_components Rt1 Rt2 /\
            (offset_writesback off
             ==> orthogonal_components Rt1 Rn /\ orthogonal_components Rt2 Rn)
         then
           let w = dimindex(:N) DIV 8 in
           memory :> wbytes addr := read Rt1 s ,,
           memory :> wbytes(word_add addr (word w)) := read Rt2 s ,,
           (if offset_writesback off
            then Rn := word_add base (offset_writeback off)
            else (=))
         else ASSIGNS entirety) s`;;

(* ------------------------------------------------------------------------- *)
(* Pseudo-instructions that are defined by ARM as aliases.                   *)
(* ------------------------------------------------------------------------- *)

let arm_BEQ = define `arm_BEQ = arm_Bcond Condition_EQ`;;
let arm_BNE = define `arm_BNE = arm_Bcond Condition_NE`;;
let arm_BCS = define `arm_BCS = arm_Bcond Condition_CS`;;
let arm_BHS = define `arm_BHS = arm_Bcond Condition_HS`;;
let arm_BCC = define `arm_BCC = arm_Bcond Condition_CC`;;
let arm_BLO = define `arm_BLO = arm_Bcond Condition_LO`;;
let arm_BMI = define `arm_BMI = arm_Bcond Condition_MI`;;
let arm_BPL = define `arm_BPL = arm_Bcond Condition_PL`;;
let arm_BVS = define `arm_BVS = arm_Bcond Condition_VS`;;
let arm_BVC = define `arm_BVC = arm_Bcond Condition_VC`;;
let arm_BHI = define `arm_BHI = arm_Bcond Condition_HI`;;
let arm_BLS = define `arm_BLS = arm_Bcond Condition_LS`;;
let arm_BGE = define `arm_BGE = arm_Bcond Condition_GE`;;
let arm_BLT = define `arm_BLT = arm_Bcond Condition_LT`;;
let arm_BGT = define `arm_BGT = arm_Bcond Condition_GT`;;
let arm_BLE = define `arm_BLE = arm_Bcond Condition_LE`;;
let arm_BAL = define `arm_BAL = arm_Bcond Condition_AL`;;
let arm_BNV = define `arm_BNV = arm_Bcond Condition_NV`;;

let arm_CINV = define
 `arm_CINV Rd Rn cc = arm_CSINV Rd Rn Rn (invert_condition cc)`;;

let arm_CNEG = define
 `arm_CNEG Rd Rn cc = arm_CSNEG Rd Rn Rn (invert_condition cc)`;;

let arm_CMN = define `arm_CMN Rm Rn = arm_ADDS ZR Rm Rn`;;
let arm_CMP = define `arm_CMP Rm Rn = arm_SUBS ZR Rm Rn`;;

let arm_CSET = define
  `arm_CSET Rd cc = arm_CSINC Rd ZR ZR (invert_condition cc)`;;

let arm_CSETM = define
  `arm_CSETM Rd cc = arm_CSINV Rd ZR ZR (invert_condition cc)`;;

(*** ARM actually aliases most/all immediate shifts LSL LSR to UBFM.
 *** But in our setting it seems much simpler to use LSLV and LSRV directly.
 *** I assume the semantics must be the same, though I didn't trace
 *** through the instances of UBFM.
 ***)

let arm_LSL = define
 `arm_LSL Rd Rm Rn = arm_LSLV Rd Rm Rn`;;

let arm_LSR = define
 `arm_LSR Rd Rm Rn = arm_LSRV Rd Rm Rn`;;

let arm_MOV = define `arm_MOV Rd Rm = arm_ORR Rd ZR Rm`;;

let arm_MNEG = define `arm_MNEG Rd Rn Rm = arm_MSUB Rd Rn Rm ZR`;;
let arm_MUL = define `arm_MUL Rd Rn Rm = arm_MADD Rd Rn Rm ZR`;;

let arm_NEG = define `arm_NEG Rd Rm = arm_SUB Rd ZR Rm`;;
let arm_NEGS = define `arm_NEGS Rd Rm = arm_SUBS Rd ZR Rm`;;

let arm_NGC = define `arm_NGC Rd Rm = arm_SBC Rd ZR Rm`;;
let arm_NGCS = define `arm_NGCS Rd Rm = arm_SBCS Rd ZR Rm`;;

let arm_ROR = define `arm_ROR Rd Rs lsb = arm_EXTR Rd Rs Rs lsb`;;

let arm_TST = define `arm_TST Rm Rn = arm_ANDS ZR Rm Rn`;;

let ARM_INSTRUCTION_ALIASES =
 [arm_BEQ; arm_BNE; arm_BCS; arm_BHS; arm_BCC;
  arm_BLO; arm_BMI; arm_BPL; arm_BVS; arm_BVC;
  arm_BHI; arm_BLS; arm_BGE; arm_BLT; arm_BGT;
  arm_BLE; arm_BAL; arm_BNV; arm_CMN; arm_CMP;
  arm_CINV; arm_CNEG; arm_CSET; arm_CSETM;
  arm_LSL; arm_LSR; arm_MOV; arm_MNEG; arm_MUL;
  arm_NEG; arm_NEGS; arm_NGC; arm_NGCS; arm_ROR;
  arm_TST];;

(* ------------------------------------------------------------------------- *)
(* The ROR alias does amount to the same thing as the word_ror operation.    *)
(* ------------------------------------------------------------------------- *)

(**** We wire in 64-bit words here, but it would work with the shift
 **** being a 6-bit immediate as well
 ****)

let arm_ROR_ALT = prove
 (`arm_ROR Rd Rs lsb =
    \s:armstate.
          let n:64 word = read Rs s
          and l:64 word = read lsb s in
          let d = word_ror n (val l) in
          (Rd := d) s`,
  GEN_REWRITE_TAC I [FUN_EQ_THM] THEN X_GEN_TAC `s:armstate` THEN
  REWRITE_TAC[arm_ROR; arm_EXTR] THEN
  CONV_TAC(TOP_DEPTH_CONV let_CONV) THEN
  ONCE_REWRITE_TAC[WORD_ROR_MOD] THEN
  SIMP_TAC[WORD_SUBWORD_JOIN_SELF; LE_REFL; LT_IMP_LE; MOD_LT_EQ;
           DIMINDEX_NONZERO]);;

(* ------------------------------------------------------------------------- *)
(* Not true aliases, but this actually reflects how the ARM manual does      *)
(* it. I guess this inverted carry trick goes back to the System/360 if not  *)
(* before, and was also the way to do subtraction with borrow on the 6502.   *)
(* http://www.righto.com/2012/12/the-6502-overflow-flag-explained.html       *)
(* The same thing for SUBS and SUBS but they don't naturally look as tidy.   *)
(* ------------------------------------------------------------------------- *)

let ARM_SBC_ALT = prove
 (`!Rd Rm Rn:(armstate,N word)component.
        arm_SBC Rd Rm Rn = arm_ADC Rd Rm (Rn :> evaluate word_not)`,
  REPEAT GEN_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
  X_GEN_TAC `s:armstate` THEN REWRITE_TAC[] THEN
  REWRITE_TAC[arm_ADC; arm_SBC; READ_COMPONENT_COMPOSE] THEN
  REWRITE_TAC[READ_WRITE_EVALUATE] THEN
  CONV_TAC(TOP_DEPTH_CONV let_CONV) THEN REWRITE_TAC[WORD_BITVAL_NOT] THEN
  AP_THM_TAC THEN AP_TERM_TAC THEN CONV_TAC WORD_RULE);;

let ARM_SBCS_ALT = prove
 (`!Rd Rm Rn:(armstate,N word)component.
        arm_SBCS Rd Rm Rn = arm_ADCS Rd Rm (Rn :> evaluate word_not)`,
  REPEAT GEN_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
  X_GEN_TAC `s:armstate` THEN REWRITE_TAC[] THEN
  REWRITE_TAC[arm_ADCS; arm_SBCS; READ_COMPONENT_COMPOSE] THEN
  REWRITE_TAC[READ_WRITE_EVALUATE] THEN
  MAP_EVERY ABBREV_TAC
   [`x = read (Rm:(armstate,N word)component) s`;
    `y = read (Rn:(armstate,N word)component) s`;
    `c = read CF s`] THEN
  CONV_TAC(TOP_DEPTH_CONV let_CONV) THEN
  REWRITE_TAC[NOCARRY_WORD_SBB; CARRY_WORD_ADC] THEN
  REWRITE_TAC[IVAL_WORD_NOT; VAL_WORD_NOT; INT_BITVAL_NOT] THEN
  REWRITE_TAC[WORD_BITVAL_NOT; WORD_NOT_AS_SUB] THEN
  REWRITE_TAC[WORD_RULE
   `word_add (word_add x (word_sub (word_neg y) d)) c =
    word_sub x (word_add y (word_sub d c))`] THEN
  REWRITE_TAC[GSYM WORD_BITVAL_NOT] THEN AP_THM_TAC THEN
  REPLICATE_TAC 3 AP_TERM_TAC THEN REWRITE_TAC[INT_ARITH
   `x + --(y + &1) + c:int = x - (y + &1 - c)`] THEN
  AP_THM_TAC THEN AP_TERM_TAC THEN AP_TERM_TAC THEN
  BOOL_CASES_TAC `c:bool` THEN ASM_REWRITE_TAC[BITVAL_CLAUSES] THEN
  MP_TAC(ISPEC `x:N word` VAL_BOUND) THEN
  MP_TAC(ISPEC `y:N word` VAL_BOUND) THEN ARITH_TAC);;

(* ------------------------------------------------------------------------- *)
(* An integer-style variant more analogous to arm_MSUB                       *)
(* ------------------------------------------------------------------------- *)

let ARM_MADD_ALT = prove
 (`!Rd Rm Rn Ra:(armstate,N word)component.
        arm_MADD Rd Rn Rm Ra =
        \s. let n:N word = read Rn s
            and m:N word = read Rm s
            and a:N word = read Ra s in
            let d:N word = iword(ival a + ival n * ival m) in
            (Rd := d) s`,
  REPEAT GEN_TAC THEN REWRITE_TAC[arm_MADD; WORD_IWORD] THEN
  ABS_TAC THEN CONV_TAC(TOP_DEPTH_CONV let_CONV) THEN
  AP_THM_TAC THEN AP_TERM_TAC THEN
  REWRITE_TAC[IWORD_EQ; GSYM INT_OF_NUM_ADD; GSYM INT_OF_NUM_MUL] THEN
  MATCH_MP_TAC(INTEGER_RULE
   `(a:int == a') (mod x) /\ (n == n') (mod x) /\ (m == m') (mod x)
    ==> (a' + n' * m' == a + n * m) (mod x)`) THEN
  REWRITE_TAC[IVAL_VAL_CONG]);;

(* ------------------------------------------------------------------------- *)
(* Alternatives with more convenient carry propagation predicates.           *)
(* ------------------------------------------------------------------------- *)

let arm_ADCS_ALT = prove
 (`arm_ADCS Rd Rm Rn =
    \s. let m = read Rm s
        and n = read Rn s
        and c = bitval(read CF s) in
        let d:int64 = word_add (word_add m n) (word c) in
        (Rd := d ,,
         NF := (ival d < &0) ,,
         ZF := (val d = 0) ,,
         CF := (2 EXP 64 <= val m + val n + c) ,,
         VF := ~(ival m + ival n + &c = ival d)) s`,
  REWRITE_TAC[arm_ADCS] THEN ABS_TAC THEN
  CONV_TAC(TOP_DEPTH_CONV let_CONV) THEN
  REWRITE_TAC[CARRY64_ADC]);;

let arm_ADDS_ALT = prove
 (`arm_ADDS Rd Rm Rn =
    \s. let m = read Rm s
        and n = read Rn s in
        let d:int64 = word_add m n in
        (Rd := d ,,
         NF := (ival d < &0) ,,
         ZF := (val d = 0) ,,
         CF := (2 EXP 64 <= val m + val n) ,,
         VF := ~(ival m + ival n = ival d)) s`,
  REWRITE_TAC[arm_ADDS] THEN ABS_TAC THEN
  CONV_TAC(TOP_DEPTH_CONV let_CONV) THEN
  REWRITE_TAC[CARRY64_ADD]);;

let arm_SBCS_ALT = prove
 (`arm_SBCS Rd Rm Rn =
    \s. let m = read Rm s
        and n = read Rn s
        and c = bitval(~read CF s) in
        let d:int64 = word_sub m (word_add n (word c)) in
        (Rd := d ,,
         NF := (ival d < &0) ,,
         ZF := (val d = 0) ,,
         CF := ~(val m < val n + c) ,,
         VF := ~(ival m - (ival n + &c) = ival d)) s`,
  REWRITE_TAC[arm_SBCS] THEN ABS_TAC THEN
  CONV_TAC(TOP_DEPTH_CONV let_CONV) THEN
  REWRITE_TAC[NOCARRY64_SBB; NOT_LT]);;

let arm_SUBS_ALT = prove
 (`arm_SUBS Rd Rm Rn =
    \s. let m = read Rm s
        and n = read Rn s in
        let d:int64 = word_sub m n in
        (Rd := d ,,
         NF := (ival d < &0) ,,
         ZF := (val d = 0) ,,
         CF := ~(val m < val n) ,,
         VF := ~(ival m - ival n = ival d)) s`,
  REWRITE_TAC[arm_SUBS] THEN ABS_TAC THEN
  CONV_TAC(TOP_DEPTH_CONV let_CONV) THEN
  REWRITE_TAC[NOCARRY64_SUB; NOT_LT]);;

let arm_CBNZ_ALT = prove
 (`arm_CBNZ Rt (off:21 word) =
        \s. (PC := if ~(val(read Rt s) = 0)
                   then word_add (word_sub (read PC s) (word 4)) (word_sx off)
                   else read PC s) s`,
  REWRITE_TAC[VAL_EQ_0; arm_CBNZ]);;

let arm_CBZ_ALT = prove
 (`arm_CBZ Rt (off:21 word) =
        \s. (PC := if val(read Rt s) = 0
                   then word_add (word_sub (read PC s) (word 4)) (word_sx off)
                   else read PC s) s`,
  REWRITE_TAC[VAL_EQ_0; arm_CBZ]);;

(* ------------------------------------------------------------------------- *)
(* MOV is an alias of MOVZ when Rm is an immediate                           *)
(* ------------------------------------------------------------------------- *)

let arm_MOVZ_ALT = prove (`imm < 65536 ==>
   arm_MOV Rd (rvalue (word imm:N word)) = arm_MOVZ Rd (word imm) 0`,
  REWRITE_TAC [arm_MOVZ; arm_ORR; arm_MOV; ZR; rvalue; read] THEN
  CONV_TAC (DEPTH_CONV let_CONV) THEN
  REWRITE_TAC [WORD_OR_0; EXP; MULT_CLAUSES; WORD_VAL; ETA_AX] THEN
  DISCH_THEN (fun th -> IMP_REWRITE_TAC [VAL_WORD_EQ; DIMINDEX_16] THEN
    CONV_TAC NUM_REDUCE_CONV THEN ACCEPT_TAC th));;

let arm_MOVK_ALT =
  REWRITE_RULE[assign; WRITE_COMPONENT_COMPOSE; read; write; subword]
    arm_MOVK;;

(* ------------------------------------------------------------------------- *)
(* Collection of standard forms of non-aliased instructions                  *)
(* We separate the load/store instructions for a different treatment.        *)
(* ------------------------------------------------------------------------- *)

let ARM_OPERATION_CLAUSES =
  map (CONV_RULE(TOP_DEPTH_CONV let_CONV) o SPEC_ALL)
      [arm_ADC; arm_ADCS_ALT; arm_ADD; arm_ADDS_ALT;
       arm_AND; arm_ANDS; arm_B; arm_BL; arm_BL_ABSOLUTE; arm_Bcond;
       arm_CBNZ_ALT; arm_CBZ_ALT; arm_CLZ; arm_CSEL; arm_CSINC;
       arm_CSINV; arm_CSNEG; arm_EON; arm_EOR; arm_EXTR; arm_LSLV;
       arm_LSRV; arm_MOVK_ALT; arm_MOVN; arm_MOVZ;
       arm_MADD; arm_MSUB; arm_ORN;
       arm_ORR; arm_RET; arm_SBC; arm_SBCS_ALT;
       arm_SUB; arm_SUBS_ALT; arm_UMULH];;

let ARM_LOAD_STORE_CLAUSES =
  map (CONV_RULE(TOP_DEPTH_CONV let_CONV) o SPEC_ALL)
      [arm_LDR; arm_STR; arm_LDP; arm_STP];;