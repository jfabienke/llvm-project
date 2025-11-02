//===-- M68kInstrAtomics.td - Atomics Instructions ---------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception //
//===----------------------------------------------------------------------===//
///
/// \file
/// M68k atomic instruction definitions
///
/// CRITICAL: CAS instructions are hardware-supported on MC68020/030/040 only.
/// The MC68060 removed CAS from hardware; execution triggers Vector 61
/// (Unimplemented Integer Instruction Exception) requiring software emulation.
///
/// Hardware Requirements:
/// - Word/Long variants require naturally aligned memory operands for atomicity
/// - Byte variant can operate on any address
/// - Locked RMW bus cycle asserted during execution (020/030/040 only)
///
/// Current Limitations:
/// - Only Address Register Indirect (An) addressing mode supported
/// - Full support for all memory alterable modes is a future enhancement
/// - See M68000 Family Programmer's Reference Manual for complete addressing modes
///
//===----------------------------------------------------------------------===//

// Atomic loads/stores use plain MOV instructions
foreach size = [8, 16, 32] in {
  def : Pat<(!cast<SDPatternOperator>("atomic_load_"#size) MxCP_ARI:$ptr),
            (!cast<MxInst>("MOV"#size#"dj") !cast<MxMemOp>("MxARI"#size):$ptr)>;

  def : Pat<(!cast<SDPatternOperator>("atomic_store_"#size) !cast<MxRegOp>("MxDRD"#size):$val, MxCP_ARI:$ptr),
            (!cast<MxInst>("MOV"#size#"jd") !cast<MxMemOp>("MxARI"#size):$ptr,
                                            !cast<MxRegOp>("MxDRD"#size):$val)>;
}

// CAS instructions - MC68020/030/040 only
let Predicates = [SupportsCAS] in {
class MxCASOp<bits<2> size_encoding, MxType type>
    : MxInst<(outs type.ROp:$out),
             (ins type.ROp:$dc, type.ROp:$du, !cast<MxMemOp>("MxARI"#type.Size):$mem),
             "cas."#type.Prefix#" $dc, $du, $mem"> {
  let Inst = (ascend
                (descend 0b00001, size_encoding, 0b011, MxEncAddrMode_j<"mem">.EA),
                (descend 0b0000000, (operand "$du", 3), 0b000, (operand "$dc", 3))
              );
  let Constraints = "$out = $dc";
  let mayLoad = 1;
  let mayStore = 1;
}

def CAS8  : MxCASOp<0x1, MxType8d>;   // Encoding: 0b01
def CAS16 : MxCASOp<0x2, MxType16d>;  // Encoding: 0b10
def CAS32 : MxCASOp<0x3, MxType32d>;  // Encoding: 0b11

// Pattern matching for atomic compare-swap
foreach size = [8, 16, 32] in {
  def : Pat<(!cast<SDPatternOperator>("atomic_cmp_swap_i"#size) MxCP_ARI:$ptr,
                                                                !cast<MxRegOp>("MxDRD"#size):$cmp,
                                                                !cast<MxRegOp>("MxDRD"#size):$new),
            (!cast<MxInst>("CAS"#size) !cast<MxRegOp>("MxDRD"#size):$cmp,
                                       !cast<MxRegOp>("MxDRD"#size):$new,
                                       !cast<MxMemOp>("MxARI"#size):$ptr)>;
}
} // let Predicates = [SupportsCAS]
