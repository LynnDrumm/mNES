;; maybe a general function for handling each mnemonic is better,
;; with some ifs depending on the mode. hm.

;;set interrupt
alias nes.cpu.mnemonic.sei {

        ;; SEI is always implict
        hadd nes.cpu status.interrupt 1

        return
}

;; clear decimal flag
alias nes.cpu.mnemonic.cld {

        ;; CLD is always implicit
        hadd nes.cpu status.decimal 0
}

;; load accumulator
alias nes.cpu.mnemonic.lda {

        var %length     $1
        var %mode       $2
        var %operand    $3

        if (%mode == immediate) {

                var %result %operand
        }

        if (%mode == absolute) {

                var %result $memRead($mergeBytes(%operand))
        }

        ;; clear negative flag if operand is #$00 - #$7F, else set it.
        hadd nes.cpu status.negative $iif(%operand <= 127, 0, 1)

        ;; set zero flag if operand is #$00
        hadd nes.cpu status.zero $iif(%operand == 0, 1, 0)

        ;; store result in accumulator
        hadd nes.cpu accumulator %result
}

;; store accumulator
alias nes.cpu.mnemonic.sta {

        var %length     $1
        var %mode       $2
        var %operand    $3-

        if (%mode == absolute) {

                var %address $mergeBytes(%operand)
        }

        ;; i don't understand this one.

        ;; the second byte of the instruction (operand)
        ;; points to a location in zeropage,
        ;; and ... ?????

        ;; we'll get to this one later. i just found problems elsewhere!

        if (%mode == indirect,y) {

                var %address %operand
        }

        memWrite %address $hget(nes.cpu, accumulator)
}

;; LoaD X index with memory
alias nes.cpu.mnemonic.ldx {

        var %length     $1
        var %mode       $2
        var %operand    $3

        if (%mode == immediate) {

                var %result %operand
        }

        ;; set negative flag equal to the 7th bit,
        ;; i assume of the operand?
        hadd nes.cpu status.negative $left($base(%operand, 10, 2, 8), 1)

        ;; set zero flag if operand is #$00, else clear it.
        hadd nes.cpu status.zero $iif(%operand == 0, 1, 0)

        ;; set x register to result
        hadd nes.cpu x %result
}

;;Transfer X to Stack
alias nes.cpu.mnemonic.txs {

        ;; always implicit

        ;; get the value from the x register
        var %value $hget(nes.cpu, x)

        ;; set negative flag equal to the 7th bit,
        ;; i assume of the byte in the x register?
        hadd nes.cpu status.negative $left($base(%value, 10, 2, 8), 1)

        ;; store the value of X into the stack
        memWrite $hget(nes.cpu, stackPointer) $hget(nes.cpu, x)

        ;; decrease stack pointer
        hdec nes.cpu stackPointer
}

;; load y index with memory
alias nes.cpu.mnemonic.ldy {

        var %length     $1
        var %mode       $2
        var %operand    $3

        if (%mode == immediate) {

                var %result %operand
        }

        ;; clear negative flag if operand is #$00 - #$7F, else set it.
        hadd nes.cpu status.negative $iif(%operand <= 127, 0, 1)

        ;; set zero flag if operand is #$00
        hadd nes.cpu status.zero $iif(%operand == 0, 1, 0)

        ;; set y register to result
        hadd nes.cpu y %result
}

alias nes.cpu.mnemonic.sty {

        var %length     $1
        var %mode       $2
        var %operand    $3

        if (%mode == zeropage) {

                ;; no need to merge anything,
                ;; since zeropage addresses are 1 byte.
                var %address %operand
        }

        ;; store the value of y at the given address.
        memWrite %address $hget(nes.cpu, y)
}

;; Logical AND memory with accumulator
alias nes.cpu.mnemonic.and {

        var %length     $1
        var %mode       $2
        var %operand    $3

        if (%mode == immediate) {

                ;; AND operand and Accumulator together
                var %result $and(%operand, $hget(nes.cpu, accumulator))
        }

        ;; clear negative flag if operand is #$00 - #$7F, else set it.
        hadd nes.cpu status.negative $iif(%operand <= 127, 0, 1)

        ;; set zero flag if operand is #$00, else clear it.
        hadd nes.cpu status.zero $iif(%operand == 0, 1, 0)

        ;; push the result to the accumulator
        hadd nes.cpu accumulator %result
}

alias nes.cpu.mnemonic.beq {

        ;; wrong. it's wrong. it's all wrong.
        ;; aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
        ;; *stabs brain with fork*

        ;; mode is always relative
        var %operand $3

        ;; get sign bit (bit 7 (8), "most significant bit")
        var %sign $left($base(%operand, 10, 2, 8), 1)

        ;; convert from decimal to binary, get the first 7 bits,
        ;; then convert back to decimal
        ;; this is totally not a stupid way to do it, shut up >.>
        var %value $base($right($base(%operand, 10, 2, 8), 7), 2, 10)

        ;; if the uppermost bit is 1, the value is negative
        if (%sign == 1) {

                var %result $calc($hget(nes.cpu, programCounter) - %value)
        }

        else {

                var %result $calc($hget(nes.cpu, programCounter) + %value)
        }

        ;; branch only if the Zero flag of the status register is 1
        if ($hget(nes.cpu, status.zero) == 1) {

                hadd nes.cpu programCounter %result
        }

        return %result
}

;; -----------------------------------------------------------------------------------------------------------------------------------

alias -l mergeBytes {

        tokenize 32 $1-

        return $dec($+($hex($1),$hex($2)))
}

alias -l dec {

        return $base($1, 16, 10)
}

alias -l hex {

        return $base($1, 10, 16)
}

;; since stupid. fuckin. starting at 1.
;; yeah. so. here's an alternative that does the extra
;; math for us.
alias -l memWrite {

        bset &RAM $calc($1 + 1) $2
}

alias -l memRead {

        return $bvar(&RAM, $calc($1 + 1))
}