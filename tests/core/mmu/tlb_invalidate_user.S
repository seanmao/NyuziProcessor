//
// Copyright 2017 Jeff Bush
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#include "mmu_test_common.h"

//
// Ensure executing tlbinval while in user mode faults and does not change the
// contents of the TLB.
//

                .globl _start
_start:         load_tlb_entries itlb_entries, dtlb_entries

                // Set trap handler
                lea s0, handle_fault
                setcr s0, CR_TRAP_HANDLER

                // Store known value on data page
                li s0, 0xdeadbeef
                li s1, 0x2234
                store_32 s0, (s1)

                // Enable MMU and switch to user mode
                move s0, FLAG_MMU_EN
                setcr s0, CR_FLAGS
                flush_pipeline

fault_pc:       tlbinval s1
                should_not_get_here

handle_fault:   getcr s0, CR_TRAP_CAUSE
                assert_reg s0, TT_PRIVILEGED_OP

                getcr s0, CR_TRAP_PC
                lea s1, fault_pc
                cmpeq_i s0, s0, s1
                bnz s0, 1f
                should_not_get_here
1:

                // Ensure MMU is still enabled
                getcr s0, CR_FLAGS
                assert_reg s0, FLAG_MMU_EN | FLAG_SUPERVISOR_EN

                // Read the first page. Ensure value is correct.
                // This ensures the tlbinval did not update the TLB.
                li s1, 0x2234
                load_32 s0, (s1)
                assert_reg s0, 0xdeadbeef

                call pass_test

itlb_entries:   .long 0x00001000, 0x00001000 | TLB_PRESENT | TLB_EXECUTABLE
                .long 0xffffffff, 0xffffffff

dtlb_entries:   .long 0x00001000, 0x00001000 | TLB_PRESENT
                .long 0x00002000, 0x00002000 | TLB_PRESENT | TLB_WRITABLE
                .long 0xffff0000, 0xffff0000 | TLB_PRESENT | TLB_WRITABLE    // I/O area
                .long 0xffffffff, 0xffffffff
