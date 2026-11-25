; test_mem.asm - teste auto-verificavel: memoria, pilha, jmpr e opcodes nao usados
;
; A cada teste aprovado, o numero do teste vai para MEM[255] (7, 8, 9).
; No final:  MEM[255] = 100 -> todos os testes passaram
;            MEM[255] = 238 -> falhou
;
; Verificacao de valor:  ldi Rc, ESPERADO / and Rc, Rx / bneq -> fail

; ---- T7: st / str / ldr ------------------------------------------------------
        ldi Ra, 0x5A
        ldi Rb, 0xF0
        str Ra, [Rb]        ; MEM[0xF0] = 0x5A
        ldi Ra, 0xA5
        st  Ra, 0xF1        ; MEM[0xF1] = 0xA5
        ldi Ra, 0
        ldr Rc, [Rb]        ; Rc = 0x5A
        ldi Rd, 0x5A
        and Rd, Rc
        ldi Rd, fail
        bneq Rd
        inc Rb              ; Rb = 0xF1
        ldr Ra, [Rb]        ; Ra = 0xA5
        ldi Rc, 0xA5
        and Rc, Ra
        bneq Rd
        ldi Ra, 7
        st  Ra, 0xFF

; ---- T8: pilha (push / pop, SP comeca em 254) --------------------------------
        ldi Ra, 11
        ldi Rb, 22
        push Ra             ; MEM[254] = 11, SP = 253
        push Rb             ; MEM[253] = 22, SP = 252
        ldi Ra, 254
        ldr Rc, [Ra]        ; Rc = MEM[254] = 11
        ldi Rd, 11
        and Rd, Rc
        ldi Rd, fail
        bneq Rd
        pop Rc              ; Rc = 22, SP = 253
        pop Ra              ; Ra = 11, SP = 254
        ldi Rb, 22
        and Rb, Rc
        bneq Rd
        ldi Rb, 11
        and Rb, Ra
        bneq Rd
        ldi Ra, 8
        st  Ra, 0xFF

; ---- T9: jmpr, mov/ldi/st nao alteram flags, opcodes nao usados = nop --------
        ldi Ra, 1
        dec Ra              ; Z = 1
        mov Rb, Ra
        ldi Rc, 0x55
        st  Rc, 0xF2
        .db 0x22, 0x23, 0x5D, 0xC4, 0xEF, 0xF5, 0xF0   ; nao usados -> nop
        ldi Rd, t9a
        bz  Rd              ; Z continua 1
        jmp fail
t9a:    ldi Rd, 0x55
        and Rd, Rc          ; Rc nao mudou com os nops
        ldi Rd, fail
        bneq Rd
        ldi Rd, t9b
        jmpr Rd
        jmp fail
t9b:    ldi Ra, 9
        st  Ra, 0xFF

; ---- fim ---------------------------------------------------------------------
pass:   ldi Ra, 100
        st  Ra, 0xFF
        halt
fail:   ldi Ra, 238
        st  Ra, 0xFF
        halt
