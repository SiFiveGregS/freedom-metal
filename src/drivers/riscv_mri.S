

#if __riscv_xlen == 32
#define REGISTER_TYPE .word
#define REGISTER_SIZE 4
#define REGISTER_STORE sw
#define REGISTER_LOAD lw
#else
#define REGISTER_TYPE .dword
#define REGISTER_SIZE 8
#define REGISTER_STORE sd
#define REGISTER_LOAD ld
#endif

#ifndef MRI_STACK_SIZE_BYTES
#define MRI_STACK_SIZE_BYTES 1024
#endif	

#define ELEMENT_TO_OFFSET(idx) idx*REGISTER_SIZE
	

#define MRI_CONTEXT_NUM_ELEMENTS 33  // flags, x1-x31, mepc

// stack usage has to maintain 16 byte alignment in order to play well with the RISC-V C ABI
#define ENTRY_STACK_FRAME_SIZE_BYTES 32
#define ENTRY_STACK_NUM_ELEMENTS ENTRY_STACK_FRAME_SIZE_BYTES/REGISTER_SIZE
#define ENTRY_STACK_ELEM_SP_OFFSET(idx) (ENTRY_STACK_NUM_ELEMENTS-(idx+1)) * REGISTER_SIZE
	

	.bss
.global mri_context	
mri_context:
	.rept MRI_CONTEXT_NUM_ELEMENTS
	// element 0 is flags (bit 0 means debug is active)
	REGISTER_TYPE 0
	.endr


	.text
.global mri_exception_entry	
mri_exception_entry:
	addi sp, sp, -ENTRY_STACK_FRAME_SIZE_BYTES

	// Save t0 and t1 values, so we can use those registers temporarily
	REGISTER_STORE t0, ENTRY_STACK_ELEM_SP_OFFSET(0)(sp)
	REGISTER_STORE t1, ENTRY_STACK_ELEM_SP_OFFSET(1)(sp)

	// Borrow t0 to hold pointer to register context that we'll fill up
	la t0, mri_context

	// borrow t1 to hold flags, branch past the context save logic if debug is already active
	REGISTER_LOAD t1, ELEMENT_TO_OFFSET(0)(t0)
	andi t1, t1, 1
	bne zero, t1, 1f

	// set active flag in context
	REGISTER_LOAD t1, ELEMENT_TO_OFFSET(0)(t0)
	ori t1, t1, 1
	REGISTER_STORE t1, ELEMENT_TO_OFFSET(0)(t0)

	// save MEPC so we can restore even if the debug agent triggers a nested exception
	//  which would ordinarily clobber MEPC (also so that debugger can modify the pc)
	csrr t1, mepc
	REGISTER_STORE t1, ELEMENT_TO_OFFSET(32)(t0)	

	// save x1/ra (still in place) to context
	REGISTER_STORE x1, ELEMENT_TO_OFFSET(1)(t0)

	// save original x2/sp to value context, no longer in-place, borrowing t1 to calculate
	addi t1, sp, ENTRY_STACK_NUM_ELEMENTS*REGISTER_SIZE
	REGISTER_STORE t1, ELEMENT_TO_OFFSET(2)(t0)

	// save original x3 (still in place) to context	
	REGISTER_STORE x3, ELEMENT_TO_OFFSET(3)(t0)

	// save original x4 (still in place) to context
	REGISTER_STORE x4, ELEMENT_TO_OFFSET(4)(t0)

	// save original t0/x5, whose value was saved off (borrow t1 to hold original t0 value)
	REGISTER_LOAD t1, ENTRY_STACK_ELEM_SP_OFFSET(0)(sp)
	REGISTER_STORE t1, ELEMENT_TO_OFFSET(5)(t0)

	// save original t1/x6, whose value was saved off (borrow t1 to hold its original value)
	REGISTER_LOAD t1, ENTRY_STACK_ELEM_SP_OFFSET(1)(sp)
	REGISTER_STORE t1, ELEMENT_TO_OFFSET(6)(t0)

	// save the rest of the gprs (values still in place) to context area
	REGISTER_STORE x7, ELEMENT_TO_OFFSET(7)(t0)
	REGISTER_STORE x8, ELEMENT_TO_OFFSET(8)(t0)
	REGISTER_STORE x9, ELEMENT_TO_OFFSET(9)(t0)
	REGISTER_STORE x10, ELEMENT_TO_OFFSET(10)(t0)
	REGISTER_STORE x11, ELEMENT_TO_OFFSET(11)(t0)
	REGISTER_STORE x12, ELEMENT_TO_OFFSET(12)(t0)
	REGISTER_STORE x13, ELEMENT_TO_OFFSET(13)(t0)
	REGISTER_STORE x14, ELEMENT_TO_OFFSET(14)(t0)
	REGISTER_STORE x15, ELEMENT_TO_OFFSET(15)(t0)
	REGISTER_STORE x16, ELEMENT_TO_OFFSET(16)(t0)
	REGISTER_STORE x17, ELEMENT_TO_OFFSET(17)(t0)
	REGISTER_STORE x18, ELEMENT_TO_OFFSET(18)(t0)
	REGISTER_STORE x19, ELEMENT_TO_OFFSET(19)(t0)
	REGISTER_STORE x20, ELEMENT_TO_OFFSET(20)(t0)
	REGISTER_STORE x21, ELEMENT_TO_OFFSET(21)(t0)
	REGISTER_STORE x22, ELEMENT_TO_OFFSET(22)(t0)
	REGISTER_STORE x23, ELEMENT_TO_OFFSET(23)(t0)
	REGISTER_STORE x24, ELEMENT_TO_OFFSET(24)(t0)
	REGISTER_STORE x25, ELEMENT_TO_OFFSET(25)(t0)
	REGISTER_STORE x26, ELEMENT_TO_OFFSET(26)(t0)
	REGISTER_STORE x27, ELEMENT_TO_OFFSET(27)(t0)
	REGISTER_STORE x28, ELEMENT_TO_OFFSET(28)(t0)
	REGISTER_STORE x29, ELEMENT_TO_OFFSET(29)(t0)
	REGISTER_STORE x30, ELEMENT_TO_OFFSET(30)(t0)
	REGISTER_STORE x31, ELEMENT_TO_OFFSET(31)(t0)

1:
	// cleanup; restore t1, t0, sp	
	REGISTER_LOAD t1, ENTRY_STACK_ELEM_SP_OFFSET(1)(sp)	
	REGISTER_LOAD t0, ENTRY_STACK_ELEM_SP_OFFSET(0)(sp)
	addi sp, sp, ENTRY_STACK_FRAME_SIZE_BYTES
	j __metal_original_exception_handler	


.global mri_exception_exit
mri_exception_exit:
	addi sp, sp, -ENTRY_STACK_NUM_ELEMENTS*REGISTER_SIZE

	// Save t0 and t1 values, so we can use those registers temporarily
	REGISTER_STORE t0, ENTRY_STACK_ELEM_SP_OFFSET(0)(sp)
	REGISTER_STORE t1, ENTRY_STACK_ELEM_SP_OFFSET(1)(sp)

	// Borrow t0 to hold pointer to register context that we'll get the register values from
	la t0, mri_context

#if 0	
	// borrow t1 to hold flags, branch past the context restore logic if debug not active
	REGISTER_LOAD t1, ELEMENT_TO_OFFSET(0)(t0)
	andi t1, t1, 1
	beq zero, t1, 1f
#endif	

	// clear active flag in context
	REGISTER_LOAD t1, ELEMENT_TO_OFFSET(0)(t0)
	xori t1, t1, 1  // we know bit 0 is currently 1, so this will clear it
	REGISTER_STORE t1, ELEMENT_TO_OFFSET(0)(t0)

	// Restore MEPC, and do it now, while we still have access to t1 before it gets restored
	REGISTER_LOAD t1, ELEMENT_TO_OFFSET(32)(t0)		
	csrw mepc, t1

	// restore x1/ra from context
	REGISTER_LOAD x1, ELEMENT_TO_OFFSET(1)(t0)

	// It should be safe to restore stack pointer at this point because if we're already here,
	// then that means we won't be using stack pointer relative accesses in this routine from this point onward
	REGISTER_LOAD sp, ELEMENT_TO_OFFSET(2)(t0)

	// Restore x3 from context
	REGISTER_LOAD x3, ELEMENT_TO_OFFSET(3)(t0)

	// Restore x4 from context	
	REGISTER_LOAD x4, ELEMENT_TO_OFFSET(4)(t0)

	// Delay restoring t0/x5 because we're still using it in this routine
	
	// It should be safe to restore t1 at this point because if we're already here,
	// then that means we won't be using t1 in this routine from this point onward
	REGISTER_LOAD t1, ELEMENT_TO_OFFSET(6)(t0)	

	// Restore the rest of the gprs except the ones we're still using
	REGISTER_LOAD x7, ELEMENT_TO_OFFSET(7)(t0)
	REGISTER_LOAD x8, ELEMENT_TO_OFFSET(8)(t0)
	REGISTER_LOAD x9, ELEMENT_TO_OFFSET(9)(t0)
	REGISTER_LOAD x10, ELEMENT_TO_OFFSET(10)(t0)
	REGISTER_LOAD x11, ELEMENT_TO_OFFSET(11)(t0)
	REGISTER_LOAD x12, ELEMENT_TO_OFFSET(12)(t0)
	REGISTER_LOAD x13, ELEMENT_TO_OFFSET(13)(t0)
	REGISTER_LOAD x14, ELEMENT_TO_OFFSET(14)(t0)
	REGISTER_LOAD x15, ELEMENT_TO_OFFSET(15)(t0)
	REGISTER_LOAD x16, ELEMENT_TO_OFFSET(16)(t0)
	REGISTER_LOAD x17, ELEMENT_TO_OFFSET(17)(t0)
	REGISTER_LOAD x18, ELEMENT_TO_OFFSET(18)(t0)
	REGISTER_LOAD x19, ELEMENT_TO_OFFSET(19)(t0)
	REGISTER_LOAD x20, ELEMENT_TO_OFFSET(20)(t0)
	REGISTER_LOAD x21, ELEMENT_TO_OFFSET(21)(t0)
	REGISTER_LOAD x22, ELEMENT_TO_OFFSET(22)(t0)
	REGISTER_LOAD x23, ELEMENT_TO_OFFSET(23)(t0)
	REGISTER_LOAD x24, ELEMENT_TO_OFFSET(24)(t0)
	REGISTER_LOAD x25, ELEMENT_TO_OFFSET(25)(t0)
	REGISTER_LOAD x26, ELEMENT_TO_OFFSET(26)(t0)
	REGISTER_LOAD x27, ELEMENT_TO_OFFSET(27)(t0)
	REGISTER_LOAD x28, ELEMENT_TO_OFFSET(28)(t0)
	REGISTER_LOAD x29, ELEMENT_TO_OFFSET(29)(t0)
	REGISTER_LOAD x30, ELEMENT_TO_OFFSET(30)(t0)
	REGISTER_LOAD x31, ELEMENT_TO_OFFSET(31)(t0)

	//  Register t0 gets restored last since we have needed its borrowed value up until this point
	REGISTER_LOAD t0, ELEMENT_TO_OFFSET(5)(t0)	
#if 0	
	j 2f  // skip the next cleanup section because that section only applies if we did not restore the register context
	
1:
	// This section only runs if we did NOT restore register from the saved context
	// cleanup; restore t1, t0, sp	
	REGISTER_LOAD t1, ENTRY_STACK_ELEM_SP_OFFSET(1)(sp)	
	REGISTER_LOAD t0, ENTRY_STACK_ELEM_SP_OFFSET(0)(sp)
	addi sp, sp, ENTRY_STACK_NUM_ELEMENTS*REGISTER_SIZE
#endif	
	mret
	

after_saving_registers:
	j after_saving_registers


after_restoring_registers:
	j after_restoring_registers
	


