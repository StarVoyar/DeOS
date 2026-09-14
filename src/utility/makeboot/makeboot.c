#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#define SECTOR_SIZE 512

// Usage:
//   makeboot disk_image bootloader.bin
int main(int argc, char **argv) {
  char *disk_file_name;
  char *bootloader_filename;
  int disk_file_descriptor;
  unsigned char data[SECTOR_SIZE];
  int sector;
  int second_stage_sector = -1;
  int bootloader_file_descriptor;
  int read_bytes;

  // Check whether the required disk image and bootloader arguments were
  // provided
  if (argc < 3) {
    printf("[Error]: Not enough arguments! \n");
    exit(-1);
  }

  disk_file_name = argv[1];
  bootloader_filename = argv[2];

  printf("Reading disk image... \n");
  disk_file_descriptor = open(disk_file_name, O_RDONLY);

  // Stop if the disk image could not be opened for reading
  if (disk_file_descriptor == -1) {
    printf("[Error]: Failed to open disk image! \n");
    exit(-2);
  }

  // Read the first sector to advance past the boot sector
  if (read(disk_file_descriptor, data, SECTOR_SIZE) == -1) {
    close(disk_file_descriptor);
    printf("[Error]: Failed to read disk image! \n");
    exit(-3);
  }

  // Scan the disk image sector by sector for the second-stage magic bytes
  for (sector = 1; sector < (10 * 1024 * 1024) / SECTOR_SIZE; ++sector) {
    printf("Checking sector: %d... \n", sector);
    read_bytes = read(disk_file_descriptor, data, SECTOR_SIZE);

    if (read_bytes == -1) {
      close(disk_file_descriptor);
      printf("[Error]: Failed to read disk image! \n");
      exit(-4);
    }

    // Stop if the end of the disk image was reached before finding the magic
    // bytes
    if (read_bytes == 0) {
      close(disk_file_descriptor);
      printf("[Error]: Failed to find magic bytes! \n");
      exit(-5);
    }

    // Check whether the sector begins with the second-stage magic bytes
    if (data[0] == 0xF4 && data[1] == 0x1C) {
      printf("Found magic bytes at sector: %d! \n", sector);
      second_stage_sector = sector;
      break;
    }
  }

  // Stop if the second stage could not be found
  if (second_stage_sector == -1) {
    close(disk_file_descriptor);
    printf("[Error]: Failed to find second stage! \n");
    exit(-5);
  }

  close(disk_file_descriptor);

  // Open the bootloader binary so it can be written to the disk image
  bootloader_file_descriptor = open(bootloader_filename, O_RDONLY);

  // Stop if the bootloader could not be opened
  if (bootloader_file_descriptor == -1) {
    printf("[Error]: Failed to open bootloader! \n");
    exit(-6);
  }

  // Read the bootloader sector into the data buffer
  if (read(bootloader_file_descriptor, data, SECTOR_SIZE) == -1) {
    printf("[Error]: Failed to read bootloader file! \n");
    close(bootloader_file_descriptor);
    exit(-7);
  }

  close(bootloader_file_descriptor);

  // Store the second-stage starting LBA in the bootloader
  memcpy(data + 0xD2, &second_stage_sector, 4);

  // Open the disk image for writing the bootloader
  disk_file_descriptor = open(disk_file_name, O_WRONLY);

  // Stop if the disk image could not be opened for writing
  if (disk_file_descriptor == -1) {
    printf("[Error]: Failed to open disk image for writing! \n");
    exit(-8);
  }

  // Write the bootloader data to the beginning of the disk image
  if (write(disk_file_descriptor, data, 0x1C0) != 0x1C0) {
    printf("[Error]: Failed to write bootloader! \n");
    close(disk_file_descriptor);
    exit(-9);
  }

  close(disk_file_descriptor);

  printf("Bootloader installed, second stage starts at LBA: %d \n",
         second_stage_sector);
}
