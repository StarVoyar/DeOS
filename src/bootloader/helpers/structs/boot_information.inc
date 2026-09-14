; Boot information structure
boot_information equ 0xA000 ; Define the boot information address
virtual at boot_information ; Define the boot information structure at its memory address
  ; Platform-independent data
  boot_information.magic_value dd 0 ; Store the boot information magic value
  boot_information.size dd 0 ; Store the size of the boot information structure
  boot_information.bootloader db 0 ; Store the bootloader type
  boot_information.frame_buffer_pointer dq 0 ; Store the frame buffer address
  boot_information.frame_buffer_width dd 0 ; Store the frame buffer width
  boot_information.frame_buffer_height dd 0 ; Store the frame buffer height
  boot_information.frame_buffer_scanline dd 0 ; Store the frame buffer scanline size
  boot_information.frame_buffer_pixelformat db 0 ; Store the frame buffer pixel format
  boot_information.unused0 dq 0, 0, 0, 0 ; Reserve unused platform-independent fields
  boot_information.unused1 db 0, 0 ; Reserve unused platform-independent fields

  ; Platform-dependent data
  boot_information.acpi_pointer dq 0 ; Store the ACPI table address
  boot_information.unused2 dq 0, 0, 0 ; Reserve unused platform-dependent fields

  ; Memory map
  boot_information.memory_map:
end virtual

; Variables
BOOTLOADER_BIOS equ 0 ; Define the BIOS bootloader identifier
BOOTLOADER_UEFI equ 1 ; Define the UEFI bootloader identifier
BOOT_INFORMATION_MAGIC_VALUE equ 'DeOS' ; Define the boot information magic value
MAX_BOOTLOADER_INFORMATION_SIZE equ 4096 ; Define the maximum bootloader information size
MEMORY_MAP_USED equ 0 ; Define the memory map used type
MEMORY_MAP_FREE equ 1 ; Define the memory map free type
MEMORY_MAP_ACPI equ 3 ; Define the memory map ACPI type
MEMORY_MAP_RECLAIMABLE equ 4 ; Define the memory map reclaimable type
