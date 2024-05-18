*= $E000

.cpu    "w65c02"

;VICKY specific defs 
MMU_MEM_CTRL    = $0000     ; MMU Memory Control Register
MMU_IO_CTRL     = $0001     ; MMU I/O Control Register

VKY_MSTR_CTRL_0 = $D000     ; Vicky Master Control Register 0
VKY_MSTR_CTRL_1 = $D001     ; Vicky Master Control Register 1

BORDER_CTRL_REG = $D004

VKY_BM0_CTRL    = $D100     ; Bitmap #0 Control Register
VKY_BM0_ADDR_L  = $D101     ; Bitmap #0 Address bits 7..0
VKY_BM0_ADDR_M  = $D102     ; Bitmap #0 Address bits 15..8
VKY_BM0_ADDR_H  = $D103     ; Bitmap #0 Address bits 17..16

VKY_BM1_CTRL    = $D108

Mstr_Ctrl_Text_Mode_En = $01 ; Enable Text Mode

;App specific defines
bitmap_base     = $0000
COLUMNS	        = 256		; Number of columns/bytes per row
HCOLOR1	        = $FF       ; FOENIX Purple color aka #106 #13 #173 aka $6A0DAD

MMU_MEM_BANK_0  = $08
MMU_MEM_BANK_1  = $09
MMU_MEM_BANK_2  = $0a
MMU_MEM_BANK_3  = $0b
MMU_MEM_BANK_4  = $0c
MMU_MEM_BANK_5  = $0d
MMU_MEM_BANK_6  = $0e
MMU_MEM_BANK_7  = $0f

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

pointer     .word ?	    ;zero page 10 and 11
defcolor    .byte ?
pencolor    .byte ?
line        .byte ?
bm_bank     .byte ?
column      .word ?
gbase_lo     .byte ?
gbase_hi     .byte ?
.send

.section kernel

; kernel section; of course there is no kernel, so this is our kernel.  This code (the set interrupt flag SEI) begins at $E002
;   and the address of hw_reset is aligned with the reset vector via the .word platform.hw_reset compiler directive above
;
; The reset sequence ends with a jmp to the begining of our small program, label 'start'

hw_nmi
rti
hw_irq
rti
hw_reset:
            stz MMU_IO_CTRL
            lda #Mstr_Ctrl_Text_Mode_En;
            sta VKY_MSTR_CTRL_0

            stz BORDER_CTRL_REG

            lda #$01
            sta MMU_IO_CTRL
            lda #<VKY_MSTR_CTRL_0
            sta pointer
            lda #>VKY_MSTR_CTRL_0
            sta pointer+1
            ldx #$00

lut_loop:
            ldy #$00
            txa
            eor #$ff ; new
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
            lda #$01
            sta $01
            lda #173
            sta $D3fc
            lda #13
            sta $D3fd
            lda #106
            sta $D3fe
            
            lda #$00
            sta $01
            lda #$40
            sta $D002
            lda #$01
            sta $D003

            stz MMU_IO_CTRL
            lda #$2C ;0C
            sta VKY_MSTR_CTRL_0    ; Save that to VICKY master control register 0
            lda #$01
            sta VKY_MSTR_CTRL_1    ; Make sure we’re just in 320x240 mode (VICKY master control register 1)
                                ;Next, it needs to set up the bitmap: setting the address, CLUT, and enabling the bitmap:
; Turn on bitmap #0
;
            stz VKY_BM1_CTRL
            lda #$01            ; Use graphics LUT #0, and enable bitmap
            sta VKY_BM0_CTRL
            lda #<bitmap_base   ; Set the low byte of the bitmap’s address
            sta VKY_BM0_ADDR_L
            lda #>bitmap_base   ; Set the middle byte of the bitmap’s address
            sta VKY_BM0_ADDR_M
            lda #1              ; Set the upper two bits of the bitmap’s address
            and #$03
            sta VKY_BM0_ADDR_H

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

            lda line        ; this code 
            inx             ;new
            cpx #$02        ;new2
            bne ckk_bra     ;new
            ldx #$00        ;new
            inc a           ; If so, increment the line number

ckk_bra:
            sta line
            cmp #200        ; If line = 240, we’re done
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

            jsr frame

done:
            nop             ; Lock up here
            jmp done 

;----------------------------------------------
            
; Draw the boundary
frame	    lda #HCOLOR1
	        ldy #$01            ; this FPGA build has line 0, and 1 offscreen so we are starting at #2
            jsr hline           ; line on the top row
	        ldy #191
	        jsr hline	        ; line on the bottom row   
            lda #HCOLOR1
            ldy #0
	        jsr vline	        ; line on the left column
	        lda #HCOLOR1
	        ldy #COLUMNS-1
	        jsr vline	        ; line on the right column
            rts

; Fetch bank routine
; given a scan line (in x register), fetch the appropriate 8K bank to $2000

ftchbnk     lda #$80            ; Turn on editing of MMU LUT #0, and work off #0
            sta MMU_MEM_CTRL
            lda bank,x
            clc
            adc #$08
            sta MMU_MEM_BANK_1
            adc #$01
            sta MMU_MEM_BANK_2
            stz MMU_MEM_CTRL
            rts

; Draw a horizontal line
hline	    pha	    
            lda table_lo,y
	        sta gbase_lo
	        lda table_hi,y
	        sta gbase_hi
            tya
            tax
            jsr ftchbnk
            ldy #COLUMNS-1	; Width of screen in bytes
            pla
_a	        sta (gbase_lo),y
            dey
	        bne _a
	        rts

; Draw a vertical line on all but the topmost and bottommost rows
; A = byte to write in each position
; Y = column
;
; Uses gbaselo, gbasehi, HCOLOR1

vline	    sta temp
	        ldx #191        ; Start at second-to-last row
_b	        lda table_lo,x      ; Get the row address
	        sta gbase_lo
	        lda table_hi,x
	        sta gbase_hi
            jsr ftchbnk     ; ADDED call to ftchbnk
	        lda temp
	        sta (gbase_lo),y	; Write the color byte
	        dex 	        ; Previous row
	        bne _b
	        rts

temp        .byte   ?

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