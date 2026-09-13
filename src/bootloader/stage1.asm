use16 ; Use 16-bit instructions
org 0x7C00 ; Load the boot sector at 0x7C00

; LBA packet structure
lba_packet equ 07E00h ; Set the LBA packet address to 0x7E00
virtual at lba_packet ; Define the structure at the LBA packet address
lba_packet.size : db ? ; Define the packet size field
lba_packet.reserved : db ? ; Define the reserved field
lba_packet.sector_count : dw ? ; Define the number of sectors to read
lba_packet.offset : dw ? ; Define the destination memory offset
lba_packet.segment : dw ? ; Define the destination memory segment
lba_packet.sector0 : dw ? ; Define the first word of the starting LBA
lba_packet.sector1 : dw ? ; Define the second word of the starting LBA
lba_packet.sector2 : dw ? ; Define the third word of the starting LBA
lba_packet.sector3 : dw ? ; Define the fourth word of the starting LBA
end virtual

; Print function macro for convenience
; Usage:
;   print string_address
macro print message {
  if ~ message eq si
    push si
    mov si, message
  end if  
    call _print
  if ~ message eq si
    pop si
  end if
}

; Panic function macro for convenience
; Usage:
;   panic string_address
macro panic message {
  if ~ message eq si
    push si
    mov si, message
  end if  
    call _panic
  if ~ message eq si
    pop si
  end if
}

.start:
  cli ; Disable maskable hardware interrupts
  cld ; Clear the direction flag so string operations increment

  xor ax, ax ; Set ax to 0
  mov ss, ax ; Set the stack segment to 0x0000
  mov es, ax ; Set the extra segment to 0x0000
  mov sp, 600h ; Set the stack pointer to 0x0600
  mov bp, 600h ; Set the base pointer to 0x0600

  push cs ; Push the current code segment onto the stack
  pop ds ; Set the data segment to the current code segment

.check_disk:
  mov byte [boot_drive], dl ; Store the BIOS boot drive number
  cmp dl, byte 080h ; Check if running from a hard drive
  jl .not_hard_drive ; Jump to .not_hard_drive if not running from a hard drive

; If running from a hard drive
.is_hard_drive:
  mov ah, byte 41h ; Set ah to 41h, the BIOS Extended Disk Drive Services check function
  mov bx, word 55AAh ; Set bx to 55AAh, the required signature for the extension check
  int 13h ; Call BIOS disk services to check for Extended Disk Drive support
  
  jc .not_lba ; Jump to .not_lba if carry flag is set (LBA is not supported)

  cmp bx, 0AA55h ; Verify the returned signature is 0xAA55
  jne .not_lba ; Jump to .not_lba if bx is not the expected signature

  test cl, byte 1 ; Test bit 0 of cl for LBA extensions
  jnz .lba_ok ; Jump to .lba_ok if LBA is supported

; Booted from a non-hard-disk drive
.not_hard_drive:
  panic not_hard_drive ; Panic not_hard_drive

; If not supporting LBA
.not_lba:
  panic lba_not_found ; Panic lba_not_found

; If LBA is ok
.lba_ok:
  mov byte [lba_packet.size], 16 ; Set packet size to 16 bytes
  mov byte [lba_packet.reserved], 0 ; Clear the reserved field
  mov word [lba_packet.sector_count], 1 ; Set number of sectors to read to 1
  mov word [lba_packet.offset], 0 ; Set destination offset to 0x0000
  mov word [lba_packet.segment], 80h ; Set the destination memory segment to 0x0080
  mov word [lba_packet.sector0], 88 ; Set starting LBA bits 0-15 to 88
  mov word [lba_packet.sector1], 0 ; Set starting LBA bits 16-31 to 0
  mov word [lba_packet.sector2], 0 ; Set starting LBA bits 32-47 to 0
  mov word [lba_packet.sector3], 0 ; Set starting LBA bits 48-63 to 0

  mov ah, 42h ; Select BIOS extended read function
  mov si, lba_packet ; Set si to the LBA packet address
  int 13h ; Call BIOS disk services
  jc .disk_read_error ; Jump to .disk_read_error if carry flag is set (Disk read failed)
  jmp .disk_read_success ; Jump to .disk_read_success if successfully read disk

.disk_read_success:
  print sector_read_success
  ; Verify the first two bytes of the loaded sector
  mov bx, [magic_bytes] ; Load the expected magic bytes into bx
  mov cx, word [800h] ; Load the first two bytes of the loaded sector into cx
  cmp cx, bx ; Compare the loaded bytes with the expected magic bytes
  jne .invalid_magic_value ; Jump to .invalid_magic_value if the magic bytes do not match
  mov ax, 802h ; Set ax to the next execution address
  jmp ax ; Jump to the address stored in ax

.invalid_magic_value:
  panic invalid_magic_value

.disk_read_error:
  panic sector_read_error

; Infinite loop
infinite_loop:
  jmp infinite_loop

; Panic function
; Usage:
;   mov si, string_address
;   call _panic
_panic:
  mov byte [newline?], 0 ; Disable newline so prefix and message stay on same line

  print panic_prefix ; Print prefix for panic messages
  print si ; Print string pointed by si

  mov byte [newline?], 1 ; Re-enable newline for normal printing

  xor ax, ax ; Prepare for wait for keypress
  int 16h ; Wait for keypress

  jmp far 0xF000:0xFFF0 ; Jump to BIOS reset vector

; Print function
; Usage:
;   mov si, string_address
;   call _print
_print:
  lodsb ; Loads string character by character to al
  or al, al ; Set the zero flag if al is 0
  jz .print_done ; Jump if al is 0 (End printing)
  
  mov ah, 0Eh ; Select BIOS teletype output function
  mov bx, 07h ; Set display page and text color
  int 10h ; Output character in al
  
  jmp _print ; Print next character

.print_done:
  ; Check if newline printing is enabled
  cmp byte [newline?], 1
  jne .skip_newline

  ; Create newline
  mov ah, 0Eh ; BIOS teletype function
  mov al, 0Dh ; Carriage return (go to column 0)
  int 10h ; Output Carriage return

  mov al, 0Ah ; Line feed (move cursor down)
  int 10h ; Output Line feed

.skip_newline:
  ret ; Return

; Variables
newline?: db 1 ; 1 = print newline, 0 = suppress newline
boot_drive: db 0 ; Define storage for the BIOS boot drive number
magic_bytes: db 0F4h, 1Ch ; Define the bootloader magic bytes
stage_2_start: dd 0xFFFFFFFF ; Define starting address of stage 2

; Strings
panic_prefix: db '[Error]: ', 0

; Success messages
sector_read_success: db 'Successfully read sector from drive!', 0

; Error messages
lba_not_found:  db 'Hard drive does not support LBA packet structure!', 0
not_hard_drive: db 'No valid hard drive found!', 0
sector_read_error: db 'Failed to read sector from drive!', 0
invalid_magic_value: db 'Sector failed to start with expected magic bytes!', 0

pad: db 510 - ($ - $$) dup 0 ; Pad until 1 sector large
boot_signature: db 55h, 0AAh ; Define drive as bootable
