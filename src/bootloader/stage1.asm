use16 ; Assemble using 16-bit instructions
org 0x600 ; Set the assembly origin to 0x0600

; LBA packet structure
lba_packet equ 07E00h ; Set the memory address of the LBA packet to 0x7E00
virtual at lba_packet ; Define the LBA packet structure at its memory address
lba_packet.size : db ? ; Store the size of the LBA packet in bytes
lba_packet.reserved : db ? ; Store the reserved byte required by the packet
lba_packet.sector_count : dw ? ; Store the number of sectors to read
lba_packet.offset : dw ? ; Store the destination memory offset
lba_packet.segment : dw ? ; Store the destination memory segment
lba_packet.sector0 : dw ? ; Store LBA bits 0-15
lba_packet.sector1 : dw ? ; Store LBA bits 16-31
lba_packet.sector2 : dw ? ; Store LBA bits 32-47
lba_packet.sector3 : dw ? ; Store LBA bits 48-63
end virtual

; Print function macro for convenience
; Usage:
;   print string_address
macro print message {
  if ~ message eq si
    push si ; Preserve the current value of SI
    mov si, message ; Load the message address into SI
  end if  
    call _print ; Call the print function
  if ~ message eq si
    pop si ; Restore the previous value of SI
  end if
}

; Panic function macro for convenience
; Usage:
;   panic string_address
macro panic message {
  if ~ message eq si
    push si ; Preserve the current value of SI
    mov si, message ; Load the error message address into SI
  end if  
    call _panic ; Call the panic function
  if ~ message eq si
    pop si ; Restore the previous value of SI
  end if
}

.start:
  cli ; Disable maskable hardware interrupts
  cld ; Clear the direction flag for forward string operations

  xor ax, ax ; Clear AX to zero
  mov ss, ax ; Set the stack segment to 0x0000
  mov es, ax ; Set the extra segment to 0x0000
  mov sp, 600h ; Set the stack pointer to offset 0x0600
  mov bp, 600h ; Set the base pointer to offset 0x0600

  push cs ; Save the current code segment on the stack
  pop ds ; Set the data segment to the current code segment
  call .relocate ; Relocate the bootloader to its execution address

.relocate:
  pop si ; Retrieve the return address into SI
  sub si, .relocate - .start ; Convert the return address to the start offset
  mov di, 0x500 ; Set the relocation destination offset to 0x0500
  mov cx, 128 ; Set the word count to 128
  repnz stosw ; Fill 128 words at ES:DI using the value in AX
  mov cx, 256 ; Set the word count to 256
  repnz movsw ; Copy 256 words from DS:SI to ES:DI
  jmp 0:.check_disk ; Continue execution from the relocated bootloader

.check_disk:
  mov byte [boot_drive], dl ; Save the BIOS boot drive number
  cmp dl, byte 080h ; Compare the boot drive number with the first hard-disk drive number
  jl .not_hard_drive ; Reject the drive if it is below 0x80

; Continue checking a hard-disk boot device
.is_hard_drive:
  mov ah, byte 41h ; Select the BIOS extension-support check function
  mov bx, word 55AAh ; Load the required 0x55AA signature into BX
  int 13h ; Call BIOS disk services
  
  jc .not_lba ; Reject the drive if the BIOS reports an error

  cmp bx, 0AA55h ; Verify that the BIOS returned the expected 0xAA55 signature
  jne .not_lba ; Reject the drive if the returned signature is incorrect

  test cl, byte 1 ; Test bit 0 of CL for LBA extension support
  jnz .lba_ok ; Continue if LBA extensions are supported

; Booted from a drive that is not a hard disk
.not_hard_drive:
  panic not_hard_drive ; Display the hard-disk error and halt

; LBA extensions are not supported
.not_lba:
  panic lba_not_found ; Display the LBA support error and halt

; LBA extensions are supported
.lba_ok:
  mov byte [lba_packet.size], 16 ; Set the LBA packet size to 16 bytes
  mov byte [lba_packet.reserved], 0 ; Clear the reserved packet field
  mov word [lba_packet.sector_count], 1 ; Request one sector from the BIOS
  mov word [lba_packet.offset], 0 ; Set the destination offset to 0x0000
  mov word [lba_packet.segment], 80h ; Set the destination segment to 0x0080
  mov word [lba_packet.sector0], 88 ; Set LBA bits 0-15 to sector 88
  mov word [lba_packet.sector1], 0 ; Clear LBA bits 16-31
  mov word [lba_packet.sector2], 0 ; Clear LBA bits 32-47
  mov word [lba_packet.sector3], 0 ; Clear LBA bits 48-63

  mov ah, 42h ; Select the BIOS extended disk read function
  mov si, lba_packet ; Point SI to the LBA packet
  int 13h ; Read the requested sector using BIOS disk services
  jc .disk_read_error ; Handle the read failure if the carry flag is set
  jmp .disk_read_success ; Continue after a successful disk read

.disk_read_success:
  print sector_read_success ; Report that the sector was read successfully
  ; Verify that the loaded sector begins with the expected magic bytes
  mov bx, [magic_bytes] ; Load the expected magic bytes into BX
  mov cx, word [800h] ; Load the first two bytes of the loaded sector into CX
  cmp cx, bx ; Compare the loaded bytes with the expected magic bytes
  jne .invalid_magic_value ; Reject the sector if the magic bytes do not match
  mov ax, 802h ; Load the next execution address into AX
  jmp ax ; Jump to the next execution address

.invalid_magic_value:
  panic invalid_magic_value ; Display the invalid magic value error and halt

.disk_read_error:
  panic sector_read_error ; Display the disk read error and halt

; Infinite loop
infinite_loop:
  jmp infinite_loop ; Continue looping indefinitely

; Panic function
; Usage:
;   mov si, string_address
;   call _panic
_panic:
  mov byte [newline?], 0 ; Disable automatic newline output

  print panic_prefix ; Print the panic message prefix
  print si ; Print the error message pointed to by SI

  mov byte [newline?], 1 ; Re-enable automatic newline output

  xor ax, ax ; Clear AX before waiting for a keypress
  int 16h ; Wait for a keyboard keypress

  jmp far 0xF000:0xFFF0 ; Jump to the BIOS reset vector

; Print function
; Usage:
;   mov si, string_address
;   call _print
_print:
  lodsb ; Load the next character from DS:SI into AL
  or al, al ; Set the zero flag when the character is null
  jz .print_done ; Finish printing when the null terminator is reached
  
  mov ah, 0Eh ; Select the BIOS teletype output function
  mov bx, 07h ; Set the display page and text attribute
  int 10h ; Display the character stored in AL
  
  jmp _print ; Continue printing the next character

.print_done:
  ; Check whether automatic newline output is enabled
  cmp byte [newline?], 1 ; Compare the newline setting with enabled
  jne .skip_newline ; Skip newline output when disabled

  ; Output a carriage return and line feed
  mov ah, 0Eh ; Select the BIOS teletype output function
  mov al, 0Dh ; Set AL to carriage return
  int 10h ; Return the cursor to the beginning of the line

  mov al, 0Ah ; Set AL to line feed
  int 10h ; Move the cursor to the next line

.skip_newline:
  ret ; Return to the caller

; Variables
newline?: db 1 ; Store whether normal printing should append a newline
boot_drive: db 0 ; Store the BIOS boot drive number
magic_bytes: db 0F4h, 1Ch ; Store the expected magic bytes for the second stage
stage_2_start: dd 0xFFFFFFFF ; Store the starting address of stage 2

; Strings
panic_prefix: db '[Error]: ', 0 ; Prefix displayed before panic messages

; Success messages
sector_read_success: db 'Successfully read sector from drive!', 0 ; Message displayed after a successful sector read

; Error messages
lba_not_found:  db 'Hard drive does not support LBA packet structure!', 0 ; Message displayed when LBA extensions are unavailable
not_hard_drive: db 'No valid hard drive found!', 0 ; Message displayed when the boot device is not a hard disk
sector_read_error: db 'Failed to read sector from drive!', 0 ; Message displayed when the BIOS disk read fails
invalid_magic_value: db 'Sector failed to start with expected magic bytes!', 0 ; Message displayed when the loaded sector has an invalid signature

pad: db 510 - ($ - $$) dup 0 ; Pad the boot sector to 510 bytes
boot_signature: db 55h, 0AAh ; Write the boot signature required by the BIOS
