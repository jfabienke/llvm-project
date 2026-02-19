//===-- M68kSchedule.td - M68k Scheduling Definitions ------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \file
/// This file contains M68k scheduler definitions including itinerary classes,
/// functional units, and processor-specific timing models.
///
/// Timing data sourced from:
///   - Motorola M68000 Family Programmer's Reference Manual
///   - MC68040 User's Manual (MC68040UM/AD)
///   - MC68060 User's Manual (MC68060UM/AD)
///
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Instruction Itinerary Classes
//===----------------------------------------------------------------------===//

// Default catch-all for any instruction not explicitly categorized.
// All instructions default to this via MxInst's itin parameter.
def IIC_DEFAULT    : InstrItinClass;

// Integer ALU operations (ADD, SUB, AND, OR, EOR, NOT, NEG, NEGX, CMP, CLR)
def IIC_ALU        : InstrItinClass;

// Sign/zero extension (EXT, EXTB)
def IIC_EXT        : InstrItinClass;

// Multiply (MULS, MULU)
def IIC_MUL        : InstrItinClass;

// Divide (DIVS, DIVU)
def IIC_DIV        : InstrItinClass;

// Register-to-register move (MOVE Dn,Dn or An,An)
def IIC_MOVE_RR    : InstrItinClass;

// Immediate to register (MOVEQ, MOVE #imm,Rn)
def IIC_MOVE_RI    : InstrItinClass;

// Register to memory store (MOVE Rn,(ea))
def IIC_MOVE_RM    : InstrItinClass;

// Memory to register load (MOVE (ea),Rn)
def IIC_MOVE_MR    : InstrItinClass;

// Memory to memory (MOVE (ea),(ea))
def IIC_MOVE_MM    : InstrItinClass;

// Multiple register move (MOVEM)
def IIC_MOVEM      : InstrItinClass;

// Load effective address (LEA)
def IIC_LEA        : InstrItinClass;

// Conditional and unconditional branches (Bcc, BRA, DBcc)
def IIC_BRANCH     : InstrItinClass;

// Indirect jump (JMP)
def IIC_JUMP       : InstrItinClass;

// Subroutine call (BSR, JSR)
def IIC_CALL       : InstrItinClass;

// Return from subroutine (RTS, RTE, RTR, RTD)
def IIC_RET        : InstrItinClass;

// Trap and exception (TRAP, TRAPV, BKPT, ILLEGAL)
def IIC_TRAP       : InstrItinClass;

// Shift and rotate (LSL, LSR, ASL, ASR, ROL, ROR, ROXL, ROXR)
def IIC_SHIFT      : InstrItinClass;

// Bit manipulation (BTST, BSET, BCLR, BCHG)
def IIC_BIT        : InstrItinClass;

// Compare and swap (CAS, CAS2)
def IIC_CAS        : InstrItinClass;

// Link/unlink (LINK, UNLK)
def IIC_LINK       : InstrItinClass;

// Set on condition (Scc)
def IIC_SCC        : InstrItinClass;

// No operation (NOP)
def IIC_NOP        : InstrItinClass;

// FPU data move (FMOVE, FMOVE to/from system registers)
def IIC_FMOVE      : InstrItinClass;

// FPU addition/subtraction (FADD, FSUB, FABS, FNEG)
def IIC_FADD       : InstrItinClass;

// FPU multiply (FMUL)
def IIC_FMUL       : InstrItinClass;

// FPU divide (FDIV)
def IIC_FDIV       : InstrItinClass;

//===----------------------------------------------------------------------===//
// Functional Units
//===----------------------------------------------------------------------===//

def ALU      : FuncUnit;  // Integer execution unit
def AGU      : FuncUnit;  // Address generation unit
def FPU_UNIT : FuncUnit;  // Floating-point unit
def MEM      : FuncUnit;  // Memory interface unit

//===----------------------------------------------------------------------===//
// M68000 Processor Itineraries (baseline, conservative timings)
//===----------------------------------------------------------------------===//
//
// The M68000 is a non-pipelined microprocessor. Cycle counts represent total
// execution time including all memory accesses and are intentionally
// conservative to account for bus arbitration and memory wait states.
//
def M68000Itineraries : ProcessorItineraries<[ALU, AGU, MEM], [], [
  InstrItinData<IIC_DEFAULT, [InstrStage<4,  [ALU]>]>,
  InstrItinData<IIC_ALU,     [InstrStage<8,  [ALU]>]>,
  InstrItinData<IIC_EXT,     [InstrStage<4,  [ALU]>]>,
  InstrItinData<IIC_MUL,     [InstrStage<70, [ALU]>]>,
  InstrItinData<IIC_DIV,     [InstrStage<158,[ALU]>]>,
  InstrItinData<IIC_MOVE_RR, [InstrStage<4,  [ALU]>]>,
  InstrItinData<IIC_MOVE_RI, [InstrStage<8,  [ALU]>]>,
  InstrItinData<IIC_MOVE_RM, [InstrStage<8,  [ALU, MEM]>]>,
  InstrItinData<IIC_MOVE_MR, [InstrStage<8,  [ALU, MEM]>]>,
  InstrItinData<IIC_MOVE_MM, [InstrStage<12, [ALU, MEM]>]>,
  InstrItinData<IIC_MOVEM,   [InstrStage<24, [ALU, MEM]>]>,
  InstrItinData<IIC_LEA,     [InstrStage<4,  [AGU]>]>,
  InstrItinData<IIC_BRANCH,  [InstrStage<10, [ALU]>]>,
  InstrItinData<IIC_JUMP,    [InstrStage<8,  [ALU]>]>,
  InstrItinData<IIC_CALL,    [InstrStage<18, [ALU, MEM]>]>,
  InstrItinData<IIC_RET,     [InstrStage<16, [ALU, MEM]>]>,
  InstrItinData<IIC_TRAP,    [InstrStage<34, [ALU]>]>,
  InstrItinData<IIC_SHIFT,   [InstrStage<8,  [ALU]>]>,
  InstrItinData<IIC_BIT,     [InstrStage<8,  [ALU]>]>,
  InstrItinData<IIC_CAS,     [InstrStage<16, [ALU, MEM]>]>,
  InstrItinData<IIC_LINK,    [InstrStage<16, [ALU, MEM]>]>,
  InstrItinData<IIC_SCC,     [InstrStage<6,  [ALU]>]>,
  InstrItinData<IIC_NOP,     [InstrStage<4,  [ALU]>]>,
  // FPU operations require 68881/68882 coprocessor interface
  InstrItinData<IIC_FMOVE,   [InstrStage<8,  [ALU]>]>,
  InstrItinData<IIC_FADD,    [InstrStage<12, [ALU]>]>,
  InstrItinData<IIC_FMUL,    [InstrStage<16, [ALU]>]>,
  InstrItinData<IIC_FDIV,    [InstrStage<72, [ALU]>]>
]>;

//===----------------------------------------------------------------------===//
// M68030 Processor Itineraries (pipelined, 3-stage)
//===----------------------------------------------------------------------===//
//
// The MC68030 introduced a 3-stage pipeline with on-chip 256-byte instruction
// and 256-byte data caches. It is significantly faster than the 68000 but
// has much smaller caches than the 68040 (256B vs 4KB). The scheduler should
// prefer compact code to avoid I-cache thrashing. Memory latency is higher
// than 68040 due to lack of burst-fill mode.
//
// Timing source: MC68030 User's Manual (MC68030UM/AD), Section 9
//
def M68030Itineraries : ProcessorItineraries<[ALU, AGU, MEM], [], [
  InstrItinData<IIC_DEFAULT, [InstrStage<2,  [ALU]>]>,
  InstrItinData<IIC_ALU,     [InstrStage<2,  [ALU]>]>,
  InstrItinData<IIC_EXT,     [InstrStage<2,  [ALU]>]>,
  InstrItinData<IIC_MUL,     [InstrStage<28, [ALU]>]>,
  InstrItinData<IIC_DIV,     [InstrStage<56, [ALU]>]>,
  InstrItinData<IIC_MOVE_RR, [InstrStage<2,  [ALU]>]>,
  InstrItinData<IIC_MOVE_RI, [InstrStage<2,  [ALU]>]>,
  InstrItinData<IIC_MOVE_RM, [InstrStage<2,  [ALU]>, InstrStage<2, [MEM]>]>,
  InstrItinData<IIC_MOVE_MR, [InstrStage<2,  [AGU]>, InstrStage<4, [MEM]>]>,
  InstrItinData<IIC_MOVE_MM, [InstrStage<2,  [AGU]>, InstrStage<4, [MEM]>]>,
  InstrItinData<IIC_MOVEM,   [InstrStage<8,  [ALU, MEM]>]>,
  InstrItinData<IIC_LEA,     [InstrStage<2,  [AGU]>]>,
  InstrItinData<IIC_BRANCH,  [InstrStage<6,  [ALU]>]>,
  InstrItinData<IIC_JUMP,    [InstrStage<4,  [ALU]>]>,
  InstrItinData<IIC_CALL,    [InstrStage<8,  [ALU, MEM]>]>,
  InstrItinData<IIC_RET,     [InstrStage<10, [ALU, MEM]>]>,
  InstrItinData<IIC_TRAP,    [InstrStage<24, [ALU]>]>,
  InstrItinData<IIC_SHIFT,   [InstrStage<4,  [ALU]>]>,
  InstrItinData<IIC_BIT,     [InstrStage<4,  [ALU]>]>,
  InstrItinData<IIC_CAS,     [InstrStage<12, [ALU, MEM]>]>,
  InstrItinData<IIC_LINK,    [InstrStage<6,  [ALU, MEM]>]>,
  InstrItinData<IIC_SCC,     [InstrStage<2,  [ALU]>]>,
  InstrItinData<IIC_NOP,     [InstrStage<2,  [ALU]>]>,
  // FPU via 68882 coprocessor interface (external chip)
  InstrItinData<IIC_FMOVE,   [InstrStage<6,  [ALU]>]>,
  InstrItinData<IIC_FADD,    [InstrStage<8,  [ALU]>]>,
  InstrItinData<IIC_FMUL,    [InstrStage<10, [ALU]>]>,
  InstrItinData<IIC_FDIV,    [InstrStage<60, [ALU]>]>
]>;

//===----------------------------------------------------------------------===//
// M68040 Processor Itineraries (pipelined, 6-stage pipeline)
//===----------------------------------------------------------------------===//
//
// The MC68040 features a 6-stage integer pipeline with separate integer and
// FPU execution units. The on-chip caches enable 1-cycle register operations
// and 3-cycle memory operations (cache hit). The 040 has a hardware barrel
// shifter (single-cycle shifts) and integrated FPU.
//
// Timing source: MC68040 User's Manual (MC68040UM/AD), Section 10
//
def M68040Itineraries : ProcessorItineraries<[ALU, AGU, FPU_UNIT, MEM], [], [
  InstrItinData<IIC_DEFAULT, [InstrStage<1,  [ALU]>]>,
  InstrItinData<IIC_ALU,     [InstrStage<1,  [ALU]>]>,
  InstrItinData<IIC_EXT,     [InstrStage<1,  [ALU]>]>,
  InstrItinData<IIC_MUL,     [InstrStage<20, [ALU]>]>,
  InstrItinData<IIC_DIV,     [InstrStage<44, [ALU]>]>,
  InstrItinData<IIC_MOVE_RR, [InstrStage<1,  [ALU]>]>,
  InstrItinData<IIC_MOVE_RI, [InstrStage<1,  [ALU]>]>,
  InstrItinData<IIC_MOVE_RM, [InstrStage<1,  [ALU]>, InstrStage<1, [MEM]>]>,
  InstrItinData<IIC_MOVE_MR, [InstrStage<1,  [AGU]>, InstrStage<3, [MEM]>]>,
  InstrItinData<IIC_MOVE_MM, [InstrStage<1,  [AGU]>, InstrStage<3, [MEM]>]>,
  InstrItinData<IIC_MOVEM,   [InstrStage<3,  [ALU, MEM]>]>,
  InstrItinData<IIC_LEA,     [InstrStage<1,  [AGU]>]>,
  InstrItinData<IIC_BRANCH,  [InstrStage<2,  [ALU]>]>,
  InstrItinData<IIC_JUMP,    [InstrStage<2,  [ALU]>]>,
  InstrItinData<IIC_CALL,    [InstrStage<3,  [ALU, MEM]>]>,
  InstrItinData<IIC_RET,     [InstrStage<5,  [ALU, MEM]>]>,
  InstrItinData<IIC_TRAP,    [InstrStage<20, [ALU]>]>,
  InstrItinData<IIC_SHIFT,   [InstrStage<1,  [ALU]>]>,
  InstrItinData<IIC_BIT,     [InstrStage<1,  [ALU]>]>,
  InstrItinData<IIC_CAS,     [InstrStage<15, [ALU, MEM]>]>,
  InstrItinData<IIC_LINK,    [InstrStage<2,  [ALU, MEM]>]>,
  InstrItinData<IIC_SCC,     [InstrStage<1,  [ALU]>]>,
  InstrItinData<IIC_NOP,     [InstrStage<1,  [ALU]>]>,
  // Integrated FPU (no coprocessor interface overhead)
  InstrItinData<IIC_FMOVE,   [InstrStage<3,  [FPU_UNIT]>]>,
  InstrItinData<IIC_FADD,    [InstrStage<3,  [FPU_UNIT]>]>,
  InstrItinData<IIC_FMUL,    [InstrStage<5,  [FPU_UNIT]>]>,
  InstrItinData<IIC_FDIV,    [InstrStage<35, [FPU_UNIT]>]>
]>;

//===----------------------------------------------------------------------===//
// M68060 Processor Itineraries (superscalar, dual-issue)
//===----------------------------------------------------------------------===//
//
// The MC68060 is a superscalar processor with dual instruction issue, branch
// prediction, and a hardware multiplier. Most integer ALU operations complete
// in 1 cycle. The 060 has the fastest integer performance of any 68k but
// emulates some FPU operations in microcode (FSIN, FCOS, etc.).
//
// Timing source: MC68060 User's Manual (MC68060UM/AD), Section 10
//
def M68060Itineraries : ProcessorItineraries<[ALU, AGU, FPU_UNIT, MEM], [], [
  InstrItinData<IIC_DEFAULT, [InstrStage<1,  [ALU]>]>,
  InstrItinData<IIC_ALU,     [InstrStage<1,  [ALU]>]>,
  InstrItinData<IIC_EXT,     [InstrStage<1,  [ALU]>]>,
  InstrItinData<IIC_MUL,     [InstrStage<2,  [ALU]>]>,
  InstrItinData<IIC_DIV,     [InstrStage<38, [ALU]>]>,
  InstrItinData<IIC_MOVE_RR, [InstrStage<1,  [ALU]>]>,
  InstrItinData<IIC_MOVE_RI, [InstrStage<1,  [ALU]>]>,
  InstrItinData<IIC_MOVE_RM, [InstrStage<1,  [ALU]>, InstrStage<1, [MEM]>]>,
  InstrItinData<IIC_MOVE_MR, [InstrStage<1,  [AGU]>, InstrStage<2, [MEM]>]>,
  InstrItinData<IIC_MOVE_MM, [InstrStage<1,  [AGU]>, InstrStage<2, [MEM]>]>,
  InstrItinData<IIC_MOVEM,   [InstrStage<2,  [ALU, MEM]>]>,
  InstrItinData<IIC_LEA,     [InstrStage<1,  [AGU]>]>,
  InstrItinData<IIC_BRANCH,  [InstrStage<1,  [ALU]>]>,
  InstrItinData<IIC_JUMP,    [InstrStage<1,  [ALU]>]>,
  InstrItinData<IIC_CALL,    [InstrStage<2,  [ALU, MEM]>]>,
  InstrItinData<IIC_RET,     [InstrStage<3,  [ALU, MEM]>]>,
  InstrItinData<IIC_TRAP,    [InstrStage<16, [ALU]>]>,
  InstrItinData<IIC_SHIFT,   [InstrStage<1,  [ALU]>]>,
  InstrItinData<IIC_BIT,     [InstrStage<1,  [ALU]>]>,
  InstrItinData<IIC_CAS,     [InstrStage<12, [ALU, MEM]>]>,
  InstrItinData<IIC_LINK,    [InstrStage<2,  [ALU, MEM]>]>,
  InstrItinData<IIC_SCC,     [InstrStage<1,  [ALU]>]>,
  InstrItinData<IIC_NOP,     [InstrStage<1,  [ALU]>]>,
  // Partially pipelined FPU
  InstrItinData<IIC_FMOVE,   [InstrStage<2,  [FPU_UNIT]>]>,
  InstrItinData<IIC_FADD,    [InstrStage<3,  [FPU_UNIT]>]>,
  InstrItinData<IIC_FMUL,    [InstrStage<3,  [FPU_UNIT]>]>,
  InstrItinData<IIC_FDIV,    [InstrStage<33, [FPU_UNIT]>]>
]>;

//===----------------------------------------------------------------------===//
// Scheduling Machine Models
//===----------------------------------------------------------------------===//

class M68kSchedModel : SchedMachineModel {
  let LoadLatency = 4;
  let HighLatency = 16;
  let PostRAScheduler = 0;
  let CompleteModel = 0;
}

def GenericM68kModel : M68kSchedModel {
  let Itineraries = M68000Itineraries;
}

def M68030SchedModel : M68kSchedModel {
  let LoadLatency = 4;
  let HighLatency = 56;
  let Itineraries = M68030Itineraries;
}

def M68040SchedModel : M68kSchedModel {
  let LoadLatency = 3;
  let HighLatency = 44;
  let Itineraries = M68040Itineraries;
}

def M68060SchedModel : M68kSchedModel {
  let LoadLatency = 2;
  let HighLatency = 38;
  let Itineraries = M68060Itineraries;
}
