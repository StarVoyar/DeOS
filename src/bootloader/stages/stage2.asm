use16 ; Assemble using 16-bit instructions
org 0x800 ; Set the assembly origin to 0x0800

magic_bytes: db 0F4h, 01Ch ; Store the expected magic bytes for the second stage

include "../helpers/print.inc" ; Include the print and panic function definitions

include "../helpers/structs/boot_information.inc" ; Include the boot information structure definitions

.start:
  xor ax, ax ; Clear AX to zero
  mov ds, ax ; Set the data segment to 0x0000
  mov es, ax ; Set the extra segment to 0x0000

.initialize_boot_information:
  mov dword eax, BOOT_INFORMATION_MAGIC_VALUE ; Load the boot information magic value into EAX
  mov dword [boot_information.magic_value], eax ; Store the boot information magic value
  mov dword [boot_information.size], 96 ; Store the initial boot information size
  mov dword [boot_information.bootloader], BOOTLOADER_BIOS ; Store the BIOS bootloader type
  xor eax, eax ; Clear EAX to zero
  mov dword [boot_information.frame_buffer_pointer], eax ; Clear the frame buffer address
  mov dword [boot_information.frame_buffer_pointer + 4], eax ; Clear the upper frame buffer address
  mov dword [boot_information.frame_buffer_width], eax ; Clear the frame buffer width
  mov dword [boot_information.frame_buffer_height], eax ; Clear the frame buffer height
  mov dword [boot_information.frame_buffer_scanline], eax ; Clear the frame buffer scanline size
  mov byte [boot_information.frame_buffer_pixelformat], 0 ; Clear the frame buffer pixel format
  mov dword [boot_information.acpi_pointer], eax ; Clear the ACPI table address
  mov dword [boot_information.acpi_pointer + 4], eax ; Clear the upper ACPI table address

; Memory map
memory_map:
  xor ebx, ebx ; Clear EBX to start the memory map
  mov word di, boot_information.memory_map ; Set DI to the memory map address

.next_memory_map:
  mov ax, 0E820h ; Select the BIOS memory map function
  mov dword edx, 0x534D4150 ; Load the required SMAP signature into EDX
  xor ecx, ecx ; Clear ECX to zero
  mov byte cl, 20 ; Request a 20-byte memory map entry
  int 15h ; Call BIOS memory services

  jc .no_memory_map ; Handle the memory map failure if the carry flag is set
  cmp eax, 0x534D4150 ; Verify that the BIOS returned the expected SMAP signature
  jne .no_memory_map ; Reject the result if the returned signature is incorrect

  mov al, [di + 16] ; Load the memory map entry type

  cmp al, MEMORY_MAP_FREE ; Compare the memory map type with free memory
  je .memory_map_free ; Continue if the memory region is free

  cmp al, MEMORY_MAP_RECLAIMABLE ; Compare the memory map type with reclaimable memory
  je .memory_map_reclaimable ; Continue if the memory region is reclaimable

  cmp al, MEMORY_MAP_ACPI ; Compare the memory map type with ACPI memory
  je .memory_map_acpi ; Continue if the memory region is ACPI memory

  mov al, MEMORY_MAP_USED ; Set the memory map type to used
  jmp @f ; Continue to store the memory map type

.memory_map_free:
  mov al, MEMORY_MAP_FREE ; Set the memory map type to free
  jmp @f ; Continue to store the memory map type

.memory_map_reclaimable:
  mov al, MEMORY_MAP_RECLAIMABLE ; Set the memory map type to reclaimable
  jmp @f ; Continue to store the memory map type

.memory_map_acpi:
  mov al, MEMORY_MAP_ACPI ; Set the memory map type to ACPI
  jmp @f ; Continue to store the memory map type

@@:
  mov byte [di], al ; Store the memory map type
  add [boot_information.size], 16 ; Increase the boot information size by 16 bytes
  add di, 16 ; Advance to the next memory map entry
  cmp di, boot_information + MAX_BOOTLOADER_INFORMATION_SIZE ; Check whether the maximum boot information size has been reached
  jae @f ; Stop mapping when the maximum boot information size is reached

  or ebx, ebx ; Check whether more memory map entries remain
  jnz .next_memory_map ; Continue if more memory map entries remain

@@:
  cmp [boot_information.size], 96 ; Check whether any memory map entries were added
  ja .memory_map_done ; Continue if the memory map contains entries

.no_memory_map:
  panic memory_map_error ; Display the memory map error and halt

.memory_map_done:
  print memory_map_success ; Report that the physical memory was mapped successfully

; Infinite loop
infinite_loop:
  jmp infinite_loop ; Continue looping indefinitely

; Variables

; Success messages
memory_map_success: db 'Successfully mapped physical memory!', 0 ; Message displayed after the physical memory is mapped

; Error messages
memory_map_error: db 'Failed to map physical memory!', 0 ; Message displayed when the memory map cannot be retrieved
