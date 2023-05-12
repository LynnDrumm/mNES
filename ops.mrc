;;SEt Interrupt
alias nes.cpu.opcode.78 {

        var %mnemonic   SEI
        var %mode       implicit
        var %length     1

        hadd nes.cpu status.interrupt 1

        return %length %mnemonic %mode
}

;; CLear Decimal
alias nes.cpu.opcode.D8 {

        var %mnemonic CLD
        var %length 1
        var %mode implicit

        hadd nes.cpu status.decimal 0

        return %length %mnemonic %mode
}

;; LoaD Accumulator
alias nes.cpu.opcode.A9 {

        var %mnemonic   LDA
        var %length     2
        var %mode       immediate
        var %operand    $getOperand(%length)

        ;; clear negative flag if operand is #$00 - #$7F, else set it.
        if (%operand <= 127) {

                hadd nes.cpu status.negative 0
        }

        else {

                hadd nes.cpu status.negative 1
        }

        ;; set zero flag if operand is #$00
        hadd nes.cpu status.zero $iif(%operand == 0, 1, 0)

        ;; set accumulator to operand
        hadd nes.cpu accumulator %operand

        return %length %mnemonic %mode %operand
}

;;STore Accumulator
alias nes.cpu.opcode.8D {

        var %mnemonic   STA
        var %length     3
        var %mode       absolute
        var %operand    $getOperand(%length)
        var %address    $convertToAddress(%operand)

        bset &RAM %address $hget(nes.cpu, accumulator)

        return %length %mnemonic %mode %address
}

;; LoaD X index with memory
alias nes.cpu.opcode.A2 {

        var %mnemonic   LDX
        var %length     2
        var %mode       immediate
        var %operand    $getOperand(%length)

        ;; set negative flag equal to the 7th bit,
        ;; i assume of the operand?
        hadd nes.cpu status.negative $left($base(%operand, 10, 2, 8), 1)

        ;; set zero flag if operand is #$00, else clear it.
        hadd nes.cpu status.zero $iif(%operand == 0, 1, 0)

        ;; set x register to operand
        hadd nes.cpu x %operand

        return %length %mnemonic %mode %operand
}

;;Transfer X to Stack pointer
alias nes.cpu.opcode.9A {

        var %mnemonic   TXS
        var %length     1
        var %mode       implicit

        ;; get the value from the x register
        var %byte $hget(nes.cpu, x)

        ;; set negative flag equal to the 7th bit,
        ;; i assume of the byte in the x register?
        hadd nes.cpu status.negative $left($base(%byte, 10, 2, 8), 1)

        ;; set zero flag if operand is #$00, else clear it.
        hadd nes.cpu status.zero $iif(%operand == 0, 1, 0)

        ;; store the value of X into the stack
        bset &RAM $hget(nes.cpu, stackPointer) $hget(nes.cpu, x)

        ;; decrease stack pointer
        hdec nes.cpu stackPointer

        return %length %mnemonic %mode
}

alias nes.cpu.opcode.AD {

        var %mnemonic   LDA
        var %length     3
        var %mode       absolute
        var %operand    $getOperand(%length)
        var %address    $convertToAddress(%operand)

        bset &RAM %address $hget(nes.cpu, accumulator)

        return %length %mnemonic %mode %address
}

;; logical AND
alias nes.cpu.opcode.29 {

        var %mnemonic   AND
        var %length     2
        var %mode       immediate
        var %operand    $getOperand(%length)

        ;; AND operand and Accumulator together
        var %result     $and(%operand, $hget(nes.cpu, accumulator))

        ;; clear negative flag if operand is #$00 - #$7F, else set it.
        hadd nes.cpu status.negative $iif(%operand <= 127, 0, 1)

        ;; set zero flag if operand is #$00, else clear it.
        hadd nes.cpu status.zero $iif(%operand == 0, 1, 0)

        ;; push the result to the accumulator
        hadd nes.cpu accumulator %result

        return %length %mnemonic %mode %operand
}

alias -l convertToAddress {

        tokenize 32 $1-

        return $dec($+($hex($1),$hex($2)))
}

;; looks at current program counter + 1, retrieves $1 - 1 bytes.
alias -l getOperand {

        return $bvar(&RAM, $calc($hget(nes.cpu, programCounter) + 1), $calc($1 - 1))
}

alias -l dec {

        return $base($1, 16, 10)
}

alias -l hex {

        return $base($1, 10, 16)
}