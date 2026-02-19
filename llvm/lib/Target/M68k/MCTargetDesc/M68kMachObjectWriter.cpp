//===-- M68kMachObjectWriter.cpp - M68k Mach-O Writer ---------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \file
/// This file implements Mach-O object file emission for M68k targets,
/// supporting GENERIC_RELOC_VANILLA, SECTDIFF, LOCAL_SECTDIFF, and PAIR
/// relocation types for NeXTSTEP static linking.
///
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/M68kFixupKinds.h"
#include "MCTargetDesc/M68kMCTargetDesc.h"
#include "llvm/ADT/Twine.h"
#include "llvm/BinaryFormat/MachO.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCMachObjectWriter.h"
#include "llvm/MC/MCSectionMachO.h"
#include "llvm/MC/MCValue.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/Format.h"

using namespace llvm;

namespace {

class M68kMachObjectWriter : public MCMachObjectTargetWriter {
  bool recordScatteredRelocation(MachObjectWriter *Writer,
                                 const MCAssembler &Asm,
                                 const MCFragment *Fragment,
                                 const MCFixup &Fixup, MCValue Target,
                                 unsigned Log2Size, uint64_t &FixedValue);

public:
  // CPU_TYPE_MC680x0 = 6, CPU_SUBTYPE_MC68040 = 2
  M68kMachObjectWriter()
      : MCMachObjectTargetWriter(/*Is64Bit=*/false,
                                 /*CPUType=*/6,
                                 /*CPUSubtype=*/2) {}

  void recordRelocation(MachObjectWriter *Writer, MCAssembler &Asm,
                        const MCFragment *Fragment, const MCFixup &Fixup,
                        MCValue Target, uint64_t &FixedValue) override;
};

} // namespace

bool M68kMachObjectWriter::recordScatteredRelocation(
    MachObjectWriter *Writer, const MCAssembler &Asm,
    const MCFragment *Fragment, const MCFixup &Fixup, MCValue Target,
    unsigned Log2Size, uint64_t &FixedValue) {
  uint64_t OriginalFixedValue = FixedValue;
  uint32_t FixupOffset = Asm.getFragmentOffset(*Fragment) + Fixup.getOffset();
  unsigned IsPCRel = Writer->isFixupKindPCRel(Asm, Fixup.getKind());
  unsigned Type = MachO::GENERIC_RELOC_VANILLA;

  // See <reloc.h>.
  const MCSymbol *A = &Target.getSymA()->getSymbol();

  if (!A->getFragment()) {
    Asm.getContext().reportError(
        Fixup.getLoc(),
        "symbol '" + A->getName() +
            "' can not be undefined in a subtraction expression");
    return false;
  }

  uint32_t Value = Writer->getSymbolAddress(*A, Asm);
  uint64_t SecAddr = Writer->getSectionAddress(A->getFragment()->getParent());
  FixedValue += SecAddr;
  uint32_t Value2 = 0;

  if (const MCSymbolRefExpr *B = Target.getSymB()) {
    const MCSymbol *SB = &B->getSymbol();

    if (!SB->getFragment()) {
      Asm.getContext().reportError(
          Fixup.getLoc(),
          "symbol '" + SB->getName() +
              "' can not be undefined in a subtraction expression");
      return false;
    }

    // Select the appropriate difference relocation type.
    // SECTDIFF for external symbols, LOCAL_SECTDIFF for local.
    Type = A->isExternal() ? (unsigned)MachO::GENERIC_RELOC_SECTDIFF
                           : (unsigned)MachO::GENERIC_RELOC_LOCAL_SECTDIFF;
    Value2 = Writer->getSymbolAddress(*SB, Asm);
    FixedValue -= Writer->getSectionAddress(SB->getFragment()->getParent());
  }

  // Relocations are written out in reverse order, so the PAIR comes first.
  if (Type == MachO::GENERIC_RELOC_SECTDIFF ||
      Type == MachO::GENERIC_RELOC_LOCAL_SECTDIFF) {
    // If the offset is too large to fit in a scattered relocation,
    // we're hosed. It's an unfortunate limitation of the MachO format.
    if (FixupOffset > 0xffffff) {
      char Buffer[32];
      format("0x%x", FixupOffset).print(Buffer, sizeof(Buffer));
      Asm.getContext().reportError(
          Fixup.getLoc(),
          Twine("Section too large, can't encode "
                "r_address (") +
              Buffer +
              ") into 24 bits of scattered "
              "relocation entry.");
      return false;
    }

    MachO::any_relocation_info MRE;
    MRE.r_word0 = ((0 << 0) |                          // r_address
                   (MachO::GENERIC_RELOC_PAIR << 24) |  // r_type
                   (Log2Size << 28) |
                   (IsPCRel << 30) |
                   MachO::R_SCATTERED);
    MRE.r_word1 = Value2;
    Writer->addRelocation(nullptr, Fragment->getParent(), MRE);
  } else {
    // If the offset is more than 24-bits, it won't fit in a scattered
    // relocation offset field, so we fall back to using a non-scattered
    // relocation.
    if (FixupOffset > 0xffffff) {
      FixedValue = OriginalFixedValue;
      return false;
    }
  }

  MachO::any_relocation_info MRE;
  MRE.r_word0 = ((FixupOffset << 0) |
                 (Type << 24) |
                 (Log2Size << 28) |
                 (IsPCRel << 30) |
                 MachO::R_SCATTERED);
  MRE.r_word1 = Value;
  Writer->addRelocation(nullptr, Fragment->getParent(), MRE);
  return true;
}

void M68kMachObjectWriter::recordRelocation(MachObjectWriter *Writer,
                                            MCAssembler &Asm,
                                            const MCFragment *Fragment,
                                            const MCFixup &Fixup,
                                            MCValue Target,
                                            uint64_t &FixedValue) {
  unsigned IsPCRel = Writer->isFixupKindPCRel(Asm, Fixup.getKind());
  unsigned Log2Size = getFixupKindLog2Size(Fixup.getKind());

  // Differences always require scattered relocations.
  if (Target.getSymB()) {
    recordScatteredRelocation(Writer, Asm, Fragment, Fixup, Target, Log2Size,
                              FixedValue);
    return;
  }

  // Get the symbol data, if any.
  const MCSymbol *A = nullptr;
  if (Target.getSymA())
    A = &Target.getSymA()->getSymbol();

  // If this is an internal relocation with an offset, it also needs a scattered
  // relocation entry.
  uint32_t Offset = Target.getConstant();
  if (IsPCRel)
    Offset += 1 << Log2Size;

  // Try to record the scattered relocation if needed. Fall back to non
  // scattered if necessary.
  if (Offset && A && !Writer->doesSymbolRequireExternRelocation(*A) &&
      recordScatteredRelocation(Writer, Asm, Fragment, Fixup, Target, Log2Size,
                                FixedValue))
    return;

  // See <reloc.h>.
  uint32_t FixupOffset = Asm.getFragmentOffset(*Fragment) + Fixup.getOffset();
  unsigned Index = 0;
  unsigned Type = 0;
  const MCSymbol *RelSymbol = nullptr;

  if (Target.isAbsolute()) { // constant
    // SymbolNum of 0 indicates the absolute section.
    Type = MachO::GENERIC_RELOC_VANILLA;
  } else {
    assert(A && "Unknown symbol data");

    // Resolve constant variables.
    if (A->isVariable()) {
      int64_t Res;
      if (A->getVariableValue()->evaluateAsAbsolute(
              Res, Asm, Writer->getSectionAddressMap())) {
        FixedValue = Res;
        return;
      }
    }

    // Check whether we need an external or internal relocation.
    if (Writer->doesSymbolRequireExternRelocation(*A)) {
      RelSymbol = A;
      // For external relocations, compensate for the addend of the symbol
      // address if the symbol is defined.
      if (!A->isUndefined())
        FixedValue -= Asm.getSymbolOffset(*A);
    } else {
      // The index is the section ordinal (1-based).
      const MCSection &Sec = A->getSection();
      Index = Sec.getOrdinal() + 1;
      FixedValue += Writer->getSectionAddress(&Sec);
    }
    if (IsPCRel)
      FixedValue -= Writer->getSectionAddress(Fragment->getParent());

    Type = MachO::GENERIC_RELOC_VANILLA;
  }

  // struct relocation_info (8 bytes)
  MachO::any_relocation_info MRE;
  MRE.r_word0 = FixupOffset;
  MRE.r_word1 =
      (Index << 0) | (IsPCRel << 24) | (Log2Size << 25) | (Type << 28);
  Writer->addRelocation(RelSymbol, Fragment->getParent(), MRE);
}

std::unique_ptr<MCObjectTargetWriter> llvm::createM68kMachObjectWriter() {
  return std::make_unique<M68kMachObjectWriter>();
}
