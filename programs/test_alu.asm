; test_alu.asm - teste auto-verificavel: ALU, flags e saltos condicionais
;
; A cada teste aprovado, o numero do teste vai para MEM[255] (1, 2, 3 ...).
; No final:  MEM[255] = 100 -> todos os testes passaram
;            MEM[255] = 238 -> falhou (MEM[254-...] nao importa; veja o ultimo
;                              numero de teste mostrado antes do 238)
;
; Verificacao de valor:  ldi Rc, ESPERADO / and Rc, Rx / bneq -> fail
; (EQUAL = (Rc == Rx), calculado pela ALU)

; ---- T1: add com carry (200 + 100 = 44, OVF=1, GT=1) -------------------------
        ldi Ra, 200
        ldi Rb, 100
        add Ra, Rb
        ldi Rd, fail
        bcc Rd              ; ha carry -> nao pode saltar
        blt Rd              ; 200 < 100 ? nao
        bz  Rd              ; resultado != 0
        bneg Rd             ; 44 e positivo
        ldi Rd, t1a
        bcs Rd              ; deve saltar
        jmp fail
t1a:    ldi Rd, t1b
        bgt Rd              ; 200 > 100 -> salta
        jmp fail
t1b:    ldi Rc, 44
        and Rc, Ra
        ldi Rd, fail
        bneq Rd
        ldi Ra, 1
        st  Ra, 0xFF

; ---- T2: sub com borrow (3 - 5 = 254, OVF=1, N=1, SM=1) ----------------------
        ldi Ra, 3
        ldi Rb, 5
        sub Ra, Rb
        ldi Rd, fail
        bcc Rd
        bgt Rd
        beq Rd
        ldi Rd, t2a
        bneg Rd
        jmp fail
t2a:    ldi Rd, t2b
        blt Rd
        jmp fail
t2b:    ldi Rc, 0xFE
        and Rc, Ra
        ldi Rd, fail
        bneq Rd
        ldi Ra, 2
        st  Ra, 0xFF

; ---- T3: zero / equal (x - x = 0, Z=1, EQ=1, OVF=0) --------------------------
        ldi Ra, 77
        mov Rb, Ra
        sub Ra, Rb
        ldi Rd, fail
        bnz Rd
        bneq Rd
        bcs Rd
        ldi Rd, t3a
        bz Rd
        jmp fail
t3a:    ldi Rd, t3b
        beq Rd
        jmp fail
t3b:    ldi Rd, t3c
        bcc Rd
        jmp fail
t3c:    ldi Ra, 3
        st  Ra, 0xFF

; ---- T4: inc / dec nos limites -----------------------------------------------
        ldi Ra, 255
        inc Ra              ; 0, OVF=1, Z=1
        ldi Rd, fail
        bnz Rd
        bcc Rd
        dec Ra              ; 255, OVF=1 (borrow), N=1
        bcc Rd
        bz  Rd
        ldi Rc, 255
        and Rc, Ra
        bneq Rd
        ldi Rb, 9
        inc Rb              ; 10, sem carry
        bcs Rd
        dec Rb
        dec Rb              ; 8
        ldi Rc, 8
        and Rc, Rb
        bneq Rd
        ldi Ra, 4
        st  Ra, 0xFF

; ---- T5: logicas -------------------------------------------------------------
        ldi Ra, 0xF0
        ldi Rb, 0x3C
        and Ra, Rb          ; 0x30
        ldi Rd, fail
        bcs Rd              ; OVF = 0 nas logicas
        ldi Rc, 0x30
        and Rc, Ra
        bneq Rd
        ldi Ra, 0xF0
        or  Ra, Rb          ; 0xFC
        ldi Rc, 0xFC
        and Rc, Ra
        bneq Rd
        ldi Ra, 0xF0
        xor Ra, Rb          ; 0xCC
        ldi Rc, 0xCC
        and Rc, Ra
        bneq Rd
        not Ra              ; 0x33
        ldi Rc, 0x33
        and Rc, Ra
        bneq Rd
        ldi Ra, 0xFF
        not Ra              ; 0 -> Z=1
        bnz Rd
        ldi Ra, 5
        st  Ra, 0xFF

; ---- T6: rotacoes e deslocamentos (0x81) -------------------------------------
        ldi Ra, 0x81
        rol Ra              ; 0x03, OVF=1
        ldi Rd, fail
        bcc Rd
        ldi Rc, 0x03
        and Rc, Ra
        bneq Rd
        ror Ra              ; 0x81, OVF=1
        bcc Rd
        ldi Rc, 0x81
        and Rc, Ra
        bneq Rd
        lsl Ra              ; 0x02, OVF=1
        bcc Rd
        ldi Rc, 0x02
        and Rc, Ra
        bneq Rd
        lsr Ra              ; 0x01, OVF=0
        bcs Rd
        ldi Rc, 0x01
        and Rc, Ra
        bneq Rd
        lsr Ra              ; 0x00, OVF=1, Z=1
        bcc Rd
        bnz Rd
        ldi Ra, 6
        st  Ra, 0xFF

; ---- fim ---------------------------------------------------------------------
pass:   ldi Ra, 100
        st  Ra, 0xFF
        halt
fail:   ldi Ra, 238
        st  Ra, 0xFF
        halt
