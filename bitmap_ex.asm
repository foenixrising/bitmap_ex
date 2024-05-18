; Sample bitmap instantiation code for the F256 platform (400 lines)
;
; Developed by Michael Weitman leveraging code from:
;  F256Manual by pweingar
;  'balls' demo by Stephen Edwards (frame code)

; See issue #16 (published May 31, 2024) of Foenix Rising
; for more on this topic http://apps.emwhite.org/foenixmarketplace
;
; DISCLAIMERS:
; This code was derived from the full 'Foenix Balls' demo, and done
; so with haste; therefore, there may be one or more "1-off" errors
; within.
; Also note; this code will not produce a PGX/PGZ or autorun header;
; instead, it will produce a .bin file which must be pushed into your
; machine @ $E000 using the Foenix Uploader
; Assembler directives are for 64TASS

*= $E000

.cpu    "w65c02"

;VICKY specific defs 
MMU_MEM_CTRL    = $0000     ; MMU Memory Control Register
MMU_IO_CTRL     = $0001     ; MMU I/O Control Register

VKY_MSTR_CTRL_0 = $D000     ; Vicky Master Control Register 0
VKY_MSTR_CTRL_1 = $D001     ; Vicky Master Control Register 1

VKY_LAYER_CTRL_0= $D002
VKY_LAYER_CTRL_1= $D003

BORDER_CTRL_REG = $D004

VKY_BM0_CTRL    = $D100     ; Bitmap #0 Control Register
VKY_BM0_ADDR_L  = $D101     ; Bitmap #0 Address bits 7..0
VKY_BM0_ADDR_M  = $D102     ; Bitmap #0 Address bits 15..8
VKY_BM0_ADDR_H  = $D103     ; Bitmap #0 Address bits 17..16

VKY_BM1_CTRL    = $D108

Mstr_Ctrl_Text_Mode_En = $01 ; Enable Text Mode

;App specific defines
bitmap_base     = $0000

COLUMNS	        = 256		; Number of columns/bytes per row (a friendly # which is 32 : 256 : 32 = 320 pixel screen)
COLOR1	        = $FF       ; FOENIX Purple color aka #106 #13 #173 aka $6A0DAD, instanciated below as collor 255

MMU_MEM_BANK_0  = $08       ; $1:0000
MMU_MEM_BANK_1  = $09       ; $1:2000
MMU_MEM_BANK_2  = $0a       ; $1:4000
MMU_MEM_BANK_3  = $0b       ; $1:6000
MMU_MEM_BANK_4  = $0c       ; $1:8000
MMU_MEM_BANK_5  = $0d       ; $1:a000
MMU_MEM_BANK_6  = $0e       ; $1:c000
MMU_MEM_BANK_7  = $0f       ; $1:e000 < most but not all of this last bank is used.  Our bitmap screen of 320x200 = 64,000 bytes
                            ;           which is $f9ff; the last 4.8 scan lines of the memory bank do not 'fit' on the screen : )

* = $0
.fill           16          ; Reserved
.dsection       zp          ; declare section for zero page (from $0)

* = $e000
.dsection kernel            ; declare section for 'kernel' (from $e00x)
.dsection program           ; declare section for program (follows above)

* = $fffa ; Hardware vectors.
.word   platform.hw_nmi
.word   platform.hw_reset
.word   platform.hw_irq

platform .namespace

.section zp ; start
; zero page addresses will be dynamically inserted following the reserved above

pointer         .word ?
defcolor        .byte ?
pencolor        .byte ?
line            .byte ?
bm_bank         .byte ?
column          .word ?
gbase_lo        .byte ?
gbase_hi        .byte ?
.send

.section kernel

; kernel section; of course there is no kernel, so this is our kernel.  This code begins at $E002 and the 
;   address of hw_reset is aligned with the reset vector via the .word platform.hw_reset compiler directive above
;
; The hw_reset is the start of program and the jmp loop is the end.  There is no input or output.
;
; WHAT IS THIS ALL ABOUT ?!
;
; This is a bitmap example which instantiates bitmap mode @ 320x200, establishes a gradiant palette, overwrites the
; last color in the palette with a custom color (purple), paints the bitmap screen with pixels ranging in creme in color
; to a light lime green, then draws a purple frame. 

hw_nmi
rti
hw_irq
rti
hw_reset:

; Code execution begins here

            stz MMU_IO_CTRL
            lda #Mstr_Ctrl_Text_Mode_En         ; text mode (for now)
            sta VKY_MSTR_CTRL_0
            stz BORDER_CTRL_REG                 ; zero disables the border

            lda #$01                            ; switch to feature bank 1 of I/O for palette manipulation
            sta MMU_IO_CTRL
            lda #<VKY_MSTR_CTRL_0               ; initalize 'pointer' to $d000; note that this is the same base
            sta pointer                         ;   address as the VICKY Master Control Register but we are in bank 1 now !!                           
            lda #>VKY_MSTR_CTRL_0               ;   IT IS EASY TO GET CONFUSED !!

            sta pointer+1
            ldx #$00

lut_loop:
            ldy #$00
            txa
            eor #$ff
            sta (pointer),y
            iny
            lda #$E0  ; green
            sta (pointer),y
            iny
            txa
            eor #$ff
            inc a
            sta (pointer),y
            iny
            inx
            beq lut_done
            clc
            lda pointer
            adc #$04
            sta pointer
            lda pointer+1
            adc #$00
            sta pointer+1
            bra lut_loop
lut_done
            lda #173            ; this is our customer purple color aka $6A0DAD
            sta $D3fc
            lda #13
            sta $D3fd
            lda #106
            sta $D3fe
            
; layer setup
            stz MMU_IO_CTRL     ; back in feature bank 0 of I/O aka, most of the graphics registers
            lda #$40            ; config for a simple tile map 0 @ layer 1 (not used); bitmap 0 at layer 0 (used)
            sta VKY_LAYER_CTRL_0
            lda #$01            ; config for bitmap 1 at layer 2 (not used)
            sta VKY_LAYER_CTRL_1

; instantiate graphic mode
            lda #$2C            ;2 (bit 5) turns sprites on; C (bits 3 and 2) turn bitmap and graphics on
            sta VKY_MSTR_CTRL_0 ; Save that to VICKY master control register 0

            lda #$01            ;1 (bit 0) enables CLK_70 mode which is 70 Hz. (640x400 text and 320 x 200 graphics)            
            sta VKY_MSTR_CTRL_1 ; Make sure we’re just in 320x200 mode (VICKY master control register 1)

; Turn on bitmap #0
            stz VKY_BM1_CTRL    ; We are not using bitmap 1

            lda #$01            ; Use graphics LUT #0, and enable bitmap
            sta VKY_BM0_CTRL
            
            lda #<bitmap_base   ; Set the low byte of the bitmap’s address
            sta VKY_BM0_ADDR_L
            lda #>bitmap_base   ; Set the middle byte of the bitmap’s address
            sta VKY_BM0_ADDR_M
            lda #1              ; Set the upper two bits of the bitmap’s address
            and #$03
            sta VKY_BM0_ADDR_H  ; The and #$03 is not necessary; this is from Peter's example; this is the $1:xxxx addr

; Set the line number to 0
;
            stz line    ; store 0 in 'line' which is the starting color for the gradient hires screen
            inc line    ; advance it 4 colors in order to skip 000 (transparent)
            inc line    ; skip 001 (we use for our ligher purple color of sprites)
            inc line    ; skip 002 (we use for our dark purple sprite shadow)
            inc line    ; skip 003 (for good measure; we may use this later)

; Calculate the bank number for the bitmap
            lda #($10000 >>13)  ; bit shift 13x aka answer = 8
            sta bm_bank

bank_loop:
            stz pointer         ; Set the pointer to start of the current bank
            lda #$20            ; starting at $2000 (page 1)
            sta pointer+1
        
; Set the column to 0
            stz column
            stz column+1
        
; Alter the LUT entries for $2000 -> $bfff
            lda #$80            ; Turn on editing of MMU LUT #0, and work off #0
            sta MMU_MEM_CTRL
            lda bm_bank
            sta MMU_MEM_BANK_1
            stz MMU_MEM_CTRL
            ldx #$00  ;new
loop2:
            lda line        ; The line number is the color of the line
            sta (pointer)

inc_column:
            inc column      ; Increment the column number
            bne chk_col
            inc column+1

chk_col:        
            lda column      ; Check to see if we have finished the row
            cmp #<320
            bne inc_point
            lda column+1
            cmp #>320
            bne inc_point

            lda line         
            inx             
            cpx #$02
            bne ckk_bra
            ldx #$00
            inc a           ; If so, increment the line number

ckk_bra:
            sta line
            cmp #200        ; If line = 200, we’re done
            beq done
            stz column      ; Set the column to 0
            stz column+1

inc_point:
            inc pointer     ; Increment pointer
            bne loop2       ; If < $4000, keep looping
            inc pointer+1
            lda pointer+1
            cmp #$40
            bne loop2
            inc bm_bank     ; Move to the next bank
            bra bank_loop   ; And start filling it

done:

            jsr frame
loop        nop             ; Lock up here
            jmp loop 

;----------------------------------------------
            
; Fetch bank routine
; given a scan line (in x register), fetch the appropriate 8K bank to $2000

ftchbnk     lda #$80            ; Turn on editing of MMU LUT #0, and work off #0
            sta MMU_MEM_CTRL
            lda bank,x          ; load value from bank table indexed by x register
            clc
            adc #$08            ; add 8; therefore, 0 = 8th bank of 8192 or the 65,536th byte of memory
            sta MMU_MEM_BANK_1
            adc #$01            ; importantly, we also grab the subsequent bank into $4000; this is necessary
            sta MMU_MEM_BANK_2  ;   to solve the jagged edge scenario (see FR issue #F5, page 4 and 6 for a
            stz MMU_MEM_CTRL    ;   detailed account of why this is necessary)
            rts

; Draw the boundary
;
; A key tenet of this scheme; column 0 is actaully the 32nd column otherwise known as address $2020
; when banked in (or bank 8 which normally lives at $1:0000 also known as the top of the screen,
; synomonous with the bottom of bitmap memory)
;
; The table is offset by hex $20 so that draws of objects in the full 'balls' demo can be accomplished
; without any CLC; ADC; operations.  This optimization is preferred but limits the scheme since it cannot
; 'print' pixels in positions 0..31 (and to maintain symmetry) or 192 to 319.
; 
frame	    lda #COLOR1         ; constant that refers to the Purple color for the frame
	        ldy #$01
            jsr hline           ; line on the top row
	        
            ldy #191
	        jsr hline	        ; line on the bottom row   
            
            lda #COLOR1
            ldy #0
	        jsr vline	        ; line on the left column
	        
            lda #COLOR1
	        ldy #COLUMNS-1
	        jsr vline	        ; line on the right column
            rts


; Draw a horizontal line on all but the topmost and bottommost rows
; A = byte (colored pixel) to write in each position
; Y = scan line to draw on
;
; Uses zero page addresses gbase_lo, gbase_hi, COLOR1 is passed in via (a)ccumulator

hline	    pha	    
            lda table_lo,y
	        sta gbase_lo
	        lda table_hi,y
	        sta gbase_hi
            tya
            tax
            jsr ftchbnk
            ldy #COLUMNS-1	    ; width of screen in bytes
            pla
_	        sta (gbase_lo),y
            dey
	        bne _
	        rts

; Draw a vertical line on all but the topmost and bottommost rows
; A = byte (colored pixel) to write in each position
; Y = column
;
; Uses zero page addresses gbase_lo, gbase_hi, COLOR1 is passed in via (a)ccumulator

vline	    sta temp
	        ldx #191            ; start at second-to-last row
_	        lda table_lo,x      ; get the row address
	        sta gbase_lo
	        lda table_hi,x
	        sta gbase_hi
            jsr ftchbnk         ; call to ftchbnk
	        lda temp
	        sta (gbase_lo),y    ; write the color byte
	        dex 	            ; previous row
	        bne _
	        rts

temp        .byte   ?

; Tables containing high and low bytes for 200 scan lines.  They assist in targeting precise bitmap memory locations
;
; example: if we were looking to write to the 3rd scan line of the screen, we would load an index
; register with 2, then grab or LDA table_hi,index and place it into a zero page address as the high byte
; and then grab table_lo,index and place it into the adjacent (prior) zero page address (65xx CPUs are little endian).
;
; a write to (zeropageaddress),x will address the x'th pixel of the indexed line

table_hi
    .text x"20212223252627282a2b2c2d2f303132"
    .text x"34353637393a3b3c3e3f202123242526"
    .text x"28292a2b2d2e2f30323334353738393a"
    .text x"3c3d3e3f21222324262728292b2c2d2e"
    .text x"30313233353637383a3b3c3d3f202122"
    .text x"24252627292a2b2c2e2f303133343536"
    .text x"38393a3b3d3e3f20222324252728292a"
    .text x"2c2d2e2f31323334363738393b3c3d3e"
    .text x"20212223252627282a2b2c2d2f303132"
    .text x"34353637393a3b3c3e3f202123242526"
    .text x"28292a2b2d2e2f30323334353738393a"
    .text x"3c3d3e3f21222324262728292b2c2d2e"
    .text x"3031323335363738"

table_lo
    .text x"2060a0e02060a0e02060a0e02060a0e0"
    .text x"2060a0e02060a0e02060a0e02060a0e0"
    .text x"2060a0e02060a0e02060a0e02060a0e0"
    .text x"2060a0e02060a0e02060a0e02060a0e0"
    .text x"2060a0e02060a0e02060a0e02060a0e0"
    .text x"2060a0e02060a0e02060a0e02060a0e0"
    .text x"2060a0e02060a0e02060a0e02060a0e0"
    .text x"2060a0e02060a0e02060a0e02060a0e0"
    .text x"2060a0e02060a0e02060a0e02060a0e0"
    .text x"2060a0e02060a0e02060a0e02060a0e0"
    .text x"2060a0e02060a0e02060a0e02060a0e0"
    .text x"2060a0e02060a0e02060a0e02060a0e0"
    .text x"2060a0e02060a0e0"

; The bank table is likewise a map of scan lines to memory banks.  As above, it trades memory (400 bytes)
; for performance.  This table is used by the bankftch routine.

bank
    .text x"00000000000000000000000000000000"
    .text x"00000000000000000000010101010101"
    .text x"01010101010101010101010101010101"
    .text x"01010101020202020202020202020202"
    .text x"02020202020202020202020202030303"
    .text x"03030303030303030303030303030303"
    .text x"03030303030303040404040404040404"
    .text x"04040404040404040404040404040404"
    .text x"05050505050505050505050505050505"
    .text x"05050505050505050505060606060606"
    .text x"06060606060606060606060606060606"
    .text x"06060606070707070707070707070707"
    .text x"070707070707070707"

.send
.endn