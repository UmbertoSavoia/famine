TARGET = famine

CC = gcc
CFLAGS = -Werror -Wextra -Werror

AS = nasm
ASFLAGS = -f elf64

LDFLAGS = -dynamic-linker /lib64/ld-linux-x86-64.so.2 -lc

RM = rm -f

#SRC_C = $(wildcard src/*.c)
SRC_A = $(wildcard src/*.s)
#OBJS = $(SRC_C:.c=.o)
OBJS += $(SRC_A:.s=.o)

all: $(TARGET)

$(TARGET) : $(OBJS)
	ld $^ -o $(TARGET) #$(LDFLAGS)

#%.o: %.c
#	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.s
	$(AS) $(ASFLAGS) $< -o $@

clean:
	$(RM) $(OBJS)

fclean: clean
	$(RM) $(TARGET)

re: fclean all