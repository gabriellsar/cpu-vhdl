; fibonacci.asm
; Mostra a sequencia de Fibonacci em MEM[255] (linha 2 do LCD):
; 0 1 1 2 3 5 8 13 21 34 55 89 144 233 e para quando a soma estoura 8 bits
; (flag OVERFLOW = carry -> bcs).
;
;   Ra = F(n-1)   Rb = F(n)   Rc = temporario   Rd = endereco de salto

        ldi Ra, 0           ; a = 0
        ldi Rb, 1           ; b = 1
        st  Ra, 0xFF        ; mostra 0
loop:   st  Rb, 0xFF        ; mostra b
        mov Rc, Rb          ; c = b
        add Rb, Ra          ; b = a + b   (atualiza as flags)
        mov Ra, Rc          ; a = c       (mov nao altera as flags)
        ldi Rd, fim
        bcs Rd              ; carry -> o proximo termo nao cabe em 8 bits
        jmp loop
fim:    halt
