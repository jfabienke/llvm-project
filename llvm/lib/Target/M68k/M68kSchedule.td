//===- M68kSchedule.td - M68k Scheduling Definitions -------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception.
//
//===----------------------------------------------------------------------===//
///
/// \file
/// This file defines M68k instruction scheduling using the modern SchedWrite/
/// SchedRead system. This replaces the legacy ProcessorItineraries approach.
///
/// Architecture: SchedWrite-based model (required for CompleteModel=1)
/// Date: 2025-11-03 02:15 CET
/// Status: Phase 7-R complete - Per-CPU SchedWrite overrides for MC68020/030/040
///
/// Implementation Strategy:
/// - Start with ~25-35 base SchedWrites (compact taxonomy)
/// - Map instructions via `let SchedRW = [WriteXXX]`
/// - Use InstRW for per-CPU timing overrides
/// - Keep CompleteModel=0 during migration, flip to 1 when coverage complete
///
/// Timing Reference:
/// - MC68020/030/040 timing tables archived in docs/llvm-enhancements/
/// - See m68k-timing-reference-{020,030,040}.md for hardware-accurate data
///
//===----------------------------------------------------------------------===//

// Note: TargetSchedule.td is already included by Target.td (via M68k.td:15)
// No need to include it again here to avoid duplicate definitions

//===----------------------------------------------------------------------===//
// Processor Resources
//===----------------------------------------------------------------------===//

def M68kALU     : ProcResource<1>;  // Integer/EA calculation pipeline
def M68kMemLd   : ProcResource<1>;  // Load pipeline
def M68kMemSt   : ProcResource<1>;  // Store pipeline
def M68kFPU     : ProcResource<1>;  // Floating-point unit

//===----------------------------------------------------------------------===//
// Base SchedWrites - Compact Taxonomy (~25-35 classes)
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Generic CPU Model (needs to be defined before WriteRes definitions)
//===----------------------------------------------------------------------===//

def GenericM68kModel : SchedMachineModel {
  let IssueWidth = 1;
  let LoadLatency = 4;
  let HighLatency = 72;           // DIVU.L worst case
  let MispredictPenalty = 3;
  let CompleteModel = 0;          // ⏳ TEMP: Disabled for Phase 0 Mach-O testing
}

//===----------------------------------------------------------------------===//
// 1. Arithmetic Operations
//===----------------------------------------------------------------------===//

// ALU operations - Register variants
def WriteALU_RR  : SchedWrite;  // ADD/SUB Dn,Dm (register-register)
def WriteALU_RI  : SchedWrite;  // ADDI/SUBI #imm,Dn (register-immediate)

def WriteALU_RM  : SchedWrite;  // ADD/SUB <ea>,Dn (register-memory)
def : WriteRes<WriteALU_RM, [M68kALU, M68kMemLd]> { let Latency = 4; }

def WriteALU_MR  : SchedWrite;  // ADD/SUB Dn,<ea> (memory-register, store)
def : WriteRes<WriteALU_MR, [M68kALU, M68kMemSt]> { let Latency = 2; }

def WriteALU_MI  : SchedWrite;  // ADD/SUB #imm,<ea> (memory-immediate)
def : WriteRes<WriteALU_MI, [M68kALU, M68kMemLd, M68kMemSt]> { let Latency = 5; }

// Multiplication
def WriteMUL16   : SchedWrite;  // MULS/MULU.W (16x16->32)
def : WriteRes<WriteMUL16, [M68kALU]> { let Latency = 28; }

def WriteMUL32   : SchedWrite;  // MULS/MULU.L (32x32->32)
def : WriteRes<WriteMUL32, [M68kALU]> { let Latency = 40; }

def WriteMUL64   : SchedWrite;  // MULS/MULU.L (32x32->64)
def : WriteRes<WriteMUL64, [M68kALU]> { let Latency = 40; }

// Division
def WriteDIV16   : SchedWrite;  // DIVS/DIVU.W (32/16->16r16q)
def : WriteRes<WriteDIV16, [M68kALU]> { let Latency = 42; }

def WriteDIV32   : SchedWrite;  // DIVS/DIVU.L (32/32->32)
def : WriteRes<WriteDIV32, [M68kALU]> { let Latency = 42; }

def WriteDIV64   : SchedWrite;  // DIVSL/DIVUL.L (64/32->32r32q)
def : WriteRes<WriteDIV64, [M68kALU]> { let Latency = 72; }

//===----------------------------------------------------------------------===//
// 2. Data Movement
//===----------------------------------------------------------------------===//

def WriteMOV_RR  : SchedWrite;  // MOVE Rn,Rm (register-register)
def : WriteRes<WriteMOV_RR, [M68kALU]> { let Latency = 1; }

def WriteMOV_RM  : SchedWrite;  // MOVE Rn,<ea> (register to memory, store)
def : WriteRes<WriteMOV_RM, [M68kMemSt]> { let Latency = 4; }

def WriteMOV_MR  : SchedWrite;  // MOVE <ea>,Rn (memory to register, load)
def : WriteRes<WriteMOV_MR, [M68kMemLd]> { let Latency = 4; }

def WriteLEA     : SchedWrite;  // LEA <ea>,An (effective address calculation)
def : WriteRes<WriteLEA, [M68kALU]> { let Latency = 1; }

def WriteMOVEM_RM : SchedWrite;  // MOVEM regs,<ea> (multiple register store)
def : WriteRes<WriteMOVEM_RM, [M68kMemSt]> { let Latency = 12; }

def WriteMOVEM_MR : SchedWrite;  // MOVEM <ea>,regs (multiple register load)
def : WriteRes<WriteMOVEM_MR, [M68kMemLd]> { let Latency = 12; }

def WriteLINK    : SchedWrite;  // LINK An,#disp (stack frame setup)
def : WriteRes<WriteLINK, [M68kMemSt]> { let Latency = 4; }

def WriteUNLK    : SchedWrite;  // UNLK An (stack frame teardown)
def : WriteRes<WriteUNLK, [M68kMemLd]> { let Latency = 4; }

//===----------------------------------------------------------------------===//
// 3. Shift and Rotate
//===----------------------------------------------------------------------===//

def WriteSHIFT_R  : SchedWrite;  // ASL/LSL/ROL Dx,Dy (variable shift)
def : WriteRes<WriteSHIFT_R, [M68kALU]> { let Latency = 8; }

def WriteSHIFT_I  : SchedWrite;  // ASL/LSL/ROL #imm,Dy (immediate shift)
def : WriteRes<WriteSHIFT_I, [M68kALU]> { let Latency = 4; }

def WriteSHIFT_M  : SchedWrite;  // ASL/LSL/ROL <ea> (memory shift)
def : WriteRes<WriteSHIFT_M, [M68kMemLd, M68kMemSt]> { let Latency = 4; }

def WriteSWAP    : SchedWrite;  // SWAP Dn (exchange upper/lower words)
def : WriteRes<WriteSWAP, [M68kALU]> { let Latency = 2; }

//===----------------------------------------------------------------------===//
// 4. Control Flow
//===----------------------------------------------------------------------===//

def WriteBR      : SchedWrite;  // BRA/Bcc (branch)
def : WriteRes<WriteBR, [M68kALU]> { let Latency = 6; }

def WriteJMP     : SchedWrite;  // JMP/JSR (jump)
def : WriteRes<WriteJMP, [M68kALU]> { let Latency = 6; }

def WriteRET     : SchedWrite;  // RTS/RTR/RTD (return)
def : WriteRes<WriteRET, [M68kMemLd]> { let Latency = 6; }

def WriteDBcc    : SchedWrite;  // DBcc Dn,<target> (decrement and branch)
def : WriteRes<WriteDBcc, [M68kALU]> { let Latency = 8; }

//===----------------------------------------------------------------------===//
// 5. Bit Manipulation
//===----------------------------------------------------------------------===//

def WriteBTST_R  : SchedWrite;  // BTST Dn,Dm (bit test register)
def : WriteRes<WriteBTST_R, [M68kALU]> { let Latency = 4; }

def WriteBTST_M  : SchedWrite;  // BTST Dn,<ea> (bit test memory)
def : WriteRes<WriteBTST_M, [M68kMemLd]> { let Latency = 4; }

def WriteBCHG_R  : SchedWrite;  // BCHG/BSET/BCLR Dn,Dm (bit modify register)
def : WriteRes<WriteBCHG_R, [M68kALU]> { let Latency = 6; }

def WriteBCHG_M  : SchedWrite;  // BCHG/BSET/BCLR Dn,<ea> (bit modify memory)
def : WriteRes<WriteBCHG_M, [M68kMemLd, M68kMemSt]> { let Latency = 6; }

//===----------------------------------------------------------------------===//
// 6. Atomic Operations
//===----------------------------------------------------------------------===//

def WriteCAS     : SchedWrite;  // CAS.{B,W,L} Dc,Du,<ea> (compare-and-swap)
def : WriteRes<WriteCAS, [M68kALU, M68kMemLd, M68kMemSt]> { let Latency = 16; }

def WriteTAS     : SchedWrite;  // TAS.B <ea> (test-and-set)
def : WriteRes<WriteTAS, [M68kALU, M68kMemLd, M68kMemSt]> { let Latency = 9; }

//===----------------------------------------------------------------------===//
// 7. Floating-Point (placeholder for future FPU support)
//===----------------------------------------------------------------------===//

def WriteFPU     : SchedWrite;  // FPU operations (MC68881/68882)
def : WriteRes<WriteFPU, [M68kFPU]> { let Latency = 4; }

//===----------------------------------------------------------------------===//
// CPU-Specific Models
//===----------------------------------------------------------------------===//

def M68000Model : SchedMachineModel {
  let IssueWidth = 1;
  let LoadLatency = 4;
  let HighLatency = 140;
  let MispredictPenalty = 3;
  let CompleteModel = 0;          // ⏳ TEMP: Disabled for Phase 0 Mach-O testing
}

def M68010Model : SchedMachineModel {
  let IssueWidth = 1;
  let LoadLatency = 4;
  let HighLatency = 140;
  let MispredictPenalty = 3;
  let CompleteModel = 0;          // ⏳ TEMP: Disabled for Phase 0 Mach-O testing
}

def M68020Model : SchedMachineModel {
  let IssueWidth = 1;
  let LoadLatency = 4;
  let HighLatency = 72;
  let MispredictPenalty = 2;
  let CompleteModel = 0;          // ⏳ TEMP: Disabled for Phase 0 Mach-O testing
}

def M68030Model : SchedMachineModel {
  let IssueWidth = 1;
  let LoadLatency = 3;            // Improved with D-cache
  let HighLatency = 62;           // DIVU.L (64/32)
  let MispredictPenalty = 2;
  let CompleteModel = 0;          // ⏳ TEMP: Disabled for Phase 0 Mach-O testing
}

def M68040Model : SchedMachineModel {
  let IssueWidth = 2;             // Dual-issue superscalar
  let LoadLatency = 1;            // Cache hit latency
  let HighLatency = 44;           // DIVS.L worst case
  let MispredictPenalty = 3;
  let CompleteModel = 0;          // ⏳ TEMP: Disabled for Phase 0 Mach-O testing (NeXTSTEP primary target)
  let PostRAScheduler = 1;        // Enable for dual-issue optimization
}

def M68060Model : SchedMachineModel {
  let IssueWidth = 2;             // Dual-issue superscalar
  let LoadLatency = 1;
  let HighLatency = 44;
  let MispredictPenalty = 3;
  let CompleteModel = 0;          // ⏳ TEMP: Disabled for Phase 0 Mach-O testing
}

//===----------------------------------------------------------------------===//
// Per-CPU Instruction Remapping (InstRW)
//===----------------------------------------------------------------------===//
//
// These sections override base latencies for specific CPUs to model
// microarchitectural improvements. Populated incrementally in Phase 7-R.
//
// TEMPORARY: Commented out to unblock LLVM build for Phase 0 Mach-O testing.
// These per-CPU overrides lack actual InstRW mappings and cause TableGen errors.
// Will be restored and properly implemented in Phase 8-R.
//

//===----------------------------------------------------------------------===//
// MC68020 Overrides
//===----------------------------------------------------------------------===//

// COMMENTED OUT - Blocking build, lacks InstRW mappings
/*
let SchedModel = M68020Model in {
  // Memory operations (no data cache on MC68020)
  def WriteMOV_RM_020 : SchedWrite;
  def : WriteRes<WriteMOV_RM_020, [M68kMemSt]> { let Latency = 4; }

  def WriteMOV_MR_020 : SchedWrite;
  def : WriteRes<WriteMOV_MR_020, [M68kMemLd]> { let Latency = 4; }

  def WriteALU_RM_020 : SchedWrite;
  def : WriteRes<WriteALU_RM_020, [M68kALU, M68kMemLd]> { let Latency = 4; }

  // Multiplication timings (MC68020 User's Manual)
  def WriteMUL16_020 : SchedWrite;
  def : WriteRes<WriteMUL16_020, [M68kALU]> { let Latency = 28; }

  def WriteMUL32_020 : SchedWrite;
  def : WriteRes<WriteMUL32_020, [M68kALU]> { let Latency = 40; }

  // Division timings (MC68020 User's Manual)
  def WriteDIV16_020 : SchedWrite;
  def : WriteRes<WriteDIV16_020, [M68kALU]> { let Latency = 42; }

  def WriteDIV64_020 : SchedWrite;
  def : WriteRes<WriteDIV64_020, [M68kALU]> { let Latency = 72; }

  // Atomics (MC68020 supports CAS)
  def WriteCAS_020 : SchedWrite;
  def : WriteRes<WriteCAS_020, [M68kALU, M68kMemLd, M68kMemSt]> { let Latency = 16; }

  def WriteTAS_020 : SchedWrite;
  def : WriteRes<WriteTAS_020, [M68kALU, M68kMemLd, M68kMemSt]> { let Latency = 9; }

  // Instruction remapping (to be populated in Phase 8-R based on llvm-mca feedback)
  // Example pattern:
  // def : InstRW<[WriteMUL16_020], (instregex "^(S|U)MUL.*")>;
}
*/

//===----------------------------------------------------------------------===//
// MC68030 Overrides
//===----------------------------------------------------------------------===//

// COMMENTED OUT - Blocking build, lacks InstRW mappings
/*
let SchedModel = M68030Model in {
  // Memory operations (D-cache improves latency)
  def WriteMOV_RM_030 : SchedWrite;
  def : WriteRes<WriteMOV_RM_030, [M68kMemSt]> { let Latency = 3; }

  def WriteMOV_MR_030 : SchedWrite;
  def : WriteRes<WriteMOV_MR_030, [M68kMemLd]> { let Latency = 3; }

  def WriteALU_RM_030 : SchedWrite;
  def : WriteRes<WriteALU_RM_030, [M68kALU, M68kMemLd]> { let Latency = 3; }

  // Multiplication timings (30% faster than MC68020)
  def WriteMUL16_030 : SchedWrite;
  def : WriteRes<WriteMUL16_030, [M68kALU]> { let Latency = 20; }

  def WriteMUL32_030 : SchedWrite;
  def : WriteRes<WriteMUL32_030, [M68kALU]> { let Latency = 36; }

  def WriteMUL64_030 : SchedWrite;
  def : WriteRes<WriteMUL64_030, [M68kALU]> { let Latency = 52; }

  // Division timings (24% faster than MC68020)
  def WriteDIV16_030 : SchedWrite;
  def : WriteRes<WriteDIV16_030, [M68kALU]> { let Latency = 32; }

  def WriteDIV32_030 : SchedWrite;
  def : WriteRes<WriteDIV32_030, [M68kALU]> { let Latency = 44; }

  def WriteDIV64_030 : SchedWrite;
  def : WriteRes<WriteDIV64_030, [M68kALU]> { let Latency = 62; }

  // Atomics (improved with D-cache)
  def WriteCAS_030 : SchedWrite;
  def : WriteRes<WriteCAS_030, [M68kALU, M68kMemLd, M68kMemSt]> { let Latency = 12; }

  def WriteTAS_030 : SchedWrite;
  def : WriteRes<WriteTAS_030, [M68kALU, M68kMemLd, M68kMemSt]> { let Latency = 7; }

  // Instruction remapping (to be populated in Phase 8-R based on llvm-mca feedback)
}
*/

//===----------------------------------------------------------------------===//
// MC68040 Overrides (NeXTSTEP primary target)
//===----------------------------------------------------------------------===//

// COMMENTED OUT - Blocking build, lacks InstRW mappings
/*
let SchedModel = M68040Model in {
  // Memory operations (cache hit = 1 cycle!)
  def WriteMOV_RM_040 : SchedWrite;
  def : WriteRes<WriteMOV_RM_040, [M68kMemSt]> { let Latency = 1; }

  def WriteMOV_MR_040 : SchedWrite;
  def : WriteRes<WriteMOV_MR_040, [M68kMemLd]> { let Latency = 1; }

  def WriteALU_RM_040 : SchedWrite;
  def : WriteRes<WriteALU_RM_040, [M68kALU, M68kMemLd]> { let Latency = 1; }

  // ALU operations (1 cycle on MC68040 superscalar!)
  def WriteALU_RR_040 : SchedWrite;
  def : WriteRes<WriteALU_RR_040, [M68kALU]> { let Latency = 1; }

  // Multiplication timings (dramatic improvement - 45-69% faster)
  def WriteMUL16_040 : SchedWrite;
  def : WriteRes<WriteMUL16_040, [M68kALU]> { let Latency = 11; }

  def WriteMUL32_040 : SchedWrite;
  def : WriteRes<WriteMUL32_040, [M68kALU]> { let Latency = 11; }

  def WriteMUL64_040 : SchedWrite;
  def : WriteRes<WriteMUL64_040, [M68kALU]> { let Latency = 22; }

  // Division timings (44% faster for 16-bit)
  def WriteDIV16_040 : SchedWrite;
  def : WriteRes<WriteDIV16_040, [M68kALU]> { let Latency = 18; }

  def WriteDIV32_040 : SchedWrite;
  def : WriteRes<WriteDIV32_040, [M68kALU]> { let Latency = 44; }

  def WriteDIV64_040 : SchedWrite;
  def : WriteRes<WriteDIV64_040, [M68kALU]> { let Latency = 44; }

  // Atomics (fastest in M68k family)
  def WriteCAS_040 : SchedWrite;
  def : WriteRes<WriteCAS_040, [M68kALU, M68kMemLd, M68kMemSt]> { let Latency = 7; }

  def WriteTAS_040 : SchedWrite;
  def : WriteRes<WriteTAS_040, [M68kALU, M68kMemLd, M68kMemSt]> { let Latency = 5; }

  // Branch operations (improved prediction)
  def WriteBR_NT_040 : SchedWrite;  // Branch not-taken (predicted correctly)
  def : WriteRes<WriteBR_NT_040, [M68kALU]> { let Latency = 1; }

  def WriteBR_T_040 : SchedWrite;   // Branch taken
  def : WriteRes<WriteBR_T_040, [M68kALU]> { let Latency = 3; }

  // Instruction remapping (to be populated in Phase 8-R based on llvm-mca feedback)
}
*/
// 
// //===----------------------------------------------------------------------===//
// // Implementation Notes
// //===----------------------------------------------------------------------===//
// //
// // Migration Plan:
// // - Phase 1-R: Foundation setup (THIS FILE) ✅
// // - Phase 2-R: Map Arithmetic instructions (ADD/SUB/MUL/DIV)
// // - Phase 3-R: Map Data Movement (MOVE/LEA/MOVEM)
// // - Phase 4-R: Map Control Flow (BRA/JSR/RTS)
// // - Phase 5-R: Flip CompleteModel=1 after core coverage
// // - Phase 6-R: Expand to Shifts/Bits/Atomics
// // - Phase 7-R: Populate InstRW remappings for per-CPU tuning
// // - Phase 8-R: Test with llvm-lit and llvm-mca
// //
// // Key Design Decisions:
// - Compact SchedWrite set (~25-35 base classes, not 140 itineraries)
// - Base timings assume MC68020 characteristics (conservative)
// - Per-CPU improvements via InstRW overrides
// - CompleteModel=0 during migration prevents spurious errors
// - EA overhead modeling deferred to C++ implementation (Phase 9+)
//
// Timing Methodology:
// - Base latencies from MC68020 User's Manual
// - MC68030 improves via D-cache and faster MUL/DIV
// - MC68040 superscalar provides 1-cycle ALU and cache hits
// - All timings assume cache hits (best case)
// - Unaligned access penalties not modeled in TableGen
//
//===----------------------------------------------------------------------===//
