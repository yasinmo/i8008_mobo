;Test Program for i8008_mobo
;By Yasin Morsli
;compile with asm8 (https://github.com/yasinmo/asm8)
;----------------------------------------
.include "defines_macros.asm"
;----------------------------------------
;Defines:
.define rle_max_count 32
;----------------------------------------
;Variables:
.base 0x0F00
    .dsb rle_p  2
    .dsb vram_p 2
    .dsb vram_nibble_p 1
    .dsb rle_counter 1
    .dsb rle_byte    1
    .dsb copy_count  2
;----------------------------------------
;Code
.org 0x0000
;----------------------------------------
init:
    ;For Emulator:
    ;jmp pgm2_copy_image
    
    inp 0
    
    cpi 1
    jtz pgm0_counter
    cpi 2
    jtz pgm1_pattern
    cpi 4
    jtz pgm2_copy_image
    
    jmp init
    
pgm0_counter:
    lai 0
    lba
    lca
    lda
    pgm0_counter_loop:
        inc
        jfz pgm0_counter_loop
            inb
            lab
            cpi 0x10
            jtc pgm0_counter_loop
                lbi 0
                ind
                lad
                out 8
                jmp pgm0_counter_loop
    
pgm1_pattern:
    lai 0
    lba
    lca
    lda
    pgm1_pattern_loop:
        inc
        jfz pgm1_pattern_loop
            inb
            lab
            cpi 0x10
            jtc pgm1_pattern_loop
                lbi 0
                ind
                lad
                ndi 1
                jtz pgm1_pattern_55
                    lai 0xAA
                    out 8
                    jmp pgm1_pattern_loop
                pgm1_pattern_55:
                    lai 0x55
                    out 8
                    jmp pgm1_pattern_loop
    
pgm2_copy_image:
    move_a8_i8 (rle_p+0), (<image)
    move_a8_i8 (rle_p+1), (>image)
    move_a8_i8 (vram_p+0), (<0x2000)
    move_a8_i8 (vram_p+1), (>0x2000)
    move_a16_i16 copy_count, 0
    move_a8_i8 vram_nibble_p, 0
    rle_loop:
        ld_a_p8 rle_p
        lba
        ndi 7
        ld_a8_a rle_byte
        lab
        srl
        srl
        srl
        adi 1
        ld_a8_a rle_counter
        
        rle_copy_loop:
            cp_a8_i8 vram_nibble_p, 1
            jfc rle_copy_loop_un
            
            rle_copy_loop_ln:
                ld_a_a8 rle_byte
                lba
                ld_a_p8 vram_p
                ndi 0xF0
                orb
                jmp rle_copy_loop_to_vram
            rle_copy_loop_un:
                ld_a_a8 rle_byte
                sll
                sll
                sll
                sll
                lba
                ld_a_p8 vram_p
                ndi 0x0F
                orb
                
            rle_copy_loop_to_vram:
                ld_p8_a vram_p
                inc_a8 vram_nibble_p
                
            cp_a8_i8 vram_nibble_p, 2
            jtc rle_copy_loop_no_inc_vram_p
                inc_a16 vram_p
                move_a8_i8 vram_nibble_p, 0
            rle_copy_loop_no_inc_vram_p:
            
            dec_a8 rle_counter
            jfz rle_copy_loop
        
        inc_a16 rle_p
        
        inc_a16 copy_count
        cp_a16_a16 copy_count, image_size
        jfz rle_loop
    
    main:
        jmp main
;----------------------------------------
;Const:
.org 0x1800
image:
    .include "pic_rle.asm"
image_size:
    .db (<(image_size-image))
    .db (>(image_size-image))
;----------------------------------------
.org 0x2000
;----------------------------------------
