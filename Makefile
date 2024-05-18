# I04P19A - String Output routine "on a budget"
# See Foenix Rising Issue #4, pg. 19, 2nd column for a description

64TASS	?= 64tass

# Default target.
# Builds and load at $E000

always: bitmap_ex.bin

clean:
	rm -f bin/*.bin
	
deepclean: clean
	find . -name "*~" -exec rm {} \;
	find . -name "*#" -exec rm {} \;


COPT = -I . -C -Wall -Werror -Wno-shadow -x --verbose-list

SOURCE	= \
	bitmap_ex.asm \

bitmap_ex.bin: Makefile $(SOURCE)
	@echo Building
	64tass $(COPT) $(filter %.asm, $^) -b -L $(basename $@).lst -o $@
	@echo

