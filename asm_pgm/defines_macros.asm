
.macro ldhl _val
    lli (<_val)
    lhi (>_val)
.endm

.macro ld_a_a8 _addr
    ldhl (_addr)
    lam
.endm

.macro ld_a8_a _addr
    ldhl (_addr)
    lma
.endm

.macro ld_a_p8 _addr
    ldhl (_addr)
    lem
    ldhl (_addr+1)
    lhm
    lle
    lam
.endm

.macro ld_p8_a _addr
    ldhl (_addr)
    lem
    ldhl (_addr+1)
    lhm
    lle
    lma
.endm

.macro srl
    ora
    rar
.endm

.macro sll
    ora
    ral
.endm

.macro move_a8_a8 _dst, _src
    lli (<_src)
    lhi (>_src)
    lam
    
    lli (<_dst)
    lhi (>_dst)
    lma
.endm

.macro move_a8_i8 _dst, _val
    lai (_val)
    
    lli (<_dst)
    lhi (>_dst)
    lma
.endm

.macro move_p8_i8 _dst, _val
    lai (_val)
    
    lli (<_dst)
    lhi (>_dst)
    lem
    lli (<(_dst+1))
    lhi (>(_dst+1))
    lhm
    lle
    lma
.endm

.macro move_a8_p8 _dst, _src
    lli (<_src)
    lhi (>_src)
    lam
    lli (<(_src+1))
    lhi (>(_src+1))
    lhm
    lla
    lam
    
    lli (<_dst)
    lhi (>_dst)
    lma
.endm

.macro move_p8_a8 _dst, _src
    lli (<_src)
    lhi (>_src)
    lam
    
    lli (<_dst)
    lhi (>_dst)
    lem
    lli (<(_dst+1))
    lhi (>(_dst+1))
    lhm
    lle
    lma
.endm

.macro move_p8_p8 _dst, _src
    lli (<_src)
    lhi (>_src)
    lam
    lli (<(_src+1))
    lhi (>(_src+1))
    lhm
    lla
    lam
    
    lli (<_dst)
    lhi (>_dst)
    lem
    lli (<(_dst+1))
    lhi (>(_dst+1))
    lhm
    lle
    lma
.endm

.macro move_a16_a16 _dst, _src
    move_a8_a8 _dst, _src
    move_a8_a8 (_dst+1), (_src+1)
.endm

.macro move_a16_i16 _dst, _val
    move_a8_i8 _dst, (<_val)
    move_a8_i8 (_dst+1), (>_val)
.endm

.macro move_a16_p16 _dst, _src
    move_a8_p8 _dst, _src
    move_a8_p8 (_dst+1), (_src+1)
.endm

.macro move_p16_a16 _dst, _src
    move_p8_a8 _dst, _src
    move_p8_a8 (_dst+1), (_src+1)
.endm

.macro move_p16_p16 _dst, _src
    move_p8_p8 _dst, _src
    move_p8_p8 (_dst+1), (_src+1)
.endm

.macro add_a8_a8 _a, _b
    lli (<_b)
    lhi (>_b)
    lam
    lli (<_a)
    lhi (>_a)
    adm
    lma
.endm

.macro add_a16_a16 _a, _b
    add8 _a, _b
    
    lli (<(_b+1))
    lhi (>(_b+1))
    lam
    lli (<(_a+1))
    lhi (>(_a+1))
    acm
    lma
.endm

.macro inc_a8 _addr
    lli (<_addr)
    lhi (>_addr)
    lem
    ine
    lme
.endm

.macro inc_a16 _addr
    lli (<_addr)
    lhi (>_addr)
    lem
    ine
    lme
    jfz inc_a16_no_inc
        lli (<(_addr+1))
        lhi (>(_addr+1))
        lem
        ine
        lme
    inc_a16_no_inc:
.endm

.macro dec_a8 _addr
    lli (<_addr)
    lhi (>_addr)
    lem
    dee
    lme
.endm

.macro dec_a16 _addr
    lli (<_addr)
    lhi (>_addr)
    lem
    dee
    lme
    jfz dec_a16_no_dec
        lli (<(_addr+1))
        lhi (>(_addr+1))
        lem
        dee
        lme
    dec_a16_no_dec:
.endm

.macro cp_a8_a8 _cp, _addr
    lli (<_addr)
    lhi (>_addr)
    lem
    
    lli (<_cp)
    lhi (>_cp)
    lam
    
    cpe
.endm

.macro cp_a8_i8 _cp, _val
    lei (_val)
    
    lli (<_cp)
    lhi (>_cp)
    lam
    
    cpe
.endm

.macro cp_a16_a16 _cp, _addr
    cp_a8_a8 (_cp+1), (_addr+1)
    jfz cp_a16_a16_end
        cp_a8_a8 (_cp+0), (_addr+0)
    cp_a16_a16_end:
.endm

.macro cp_a16_i16 _cp, _val
    cp_a8_i8 (_cp+1), (>_val)
    jfz cp_a16_i16_end
        cp_a8_i8 (_cp+0), (<_val)
    cp_a16_i16_end:
.endm

