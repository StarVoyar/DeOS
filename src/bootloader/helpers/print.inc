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
    call _panic ; Call the error function
  if ~ message eq si
    pop si ; Restore the previous value of SI
  end if
}

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
  jz .print_done ; Finish printing when the character is null

  mov ah, 0Eh ; Select the BIOS teletype output function
  mov bx, 07h ; Set the display page and text attribute
  push ds ; Preserve DS across the BIOS call
  push si ; Preserve SI across the BIOS call
  int 10h ; Display the character stored in AL
  pop si ; Restore SI after the BIOS call
  pop ds ; Restore DS after the BIOS call

  jmp _print ; Continue printing the next character

.print_done:
  ; Check whether automatic newline output is enabled
  cmp byte [newline?], 1 ; Compare the newline setting with enabled
  jne .skip_newline ; Skip newline output when disabled

  ; Output a carriage return and line feed
  mov ah, 0Eh ; Select the BIOS teletype output function
  mov al, 0Dh ; Set AL to carriage return
  push ds ; Preserve DS across the BIOS call
  push si ; Preserve SI across the BIOS call
  int 10h ; Return the cursor to the beginning of the line
  pop si ; Restore SI after the BIOS call
  pop ds ; Restore DS after the BIOS call

  mov al, 0Ah ; Set AL to line feed
  push ds ; Preserve DS across the BIOS call
  push si ; Preserve SI across the BIOS call
  int 10h ; Move the cursor to the next line
  pop si ; Restore SI after the BIOS call
  pop ds ; Restore DS after the BIOS call

.skip_newline:
  ret ; Return to the caller

; Variables
newline?: db 1 ; Store whether normal printing should append a newline

; Strings
panic_prefix: db '[Error]: ', 0 ; Prefix displayed before panic messages
