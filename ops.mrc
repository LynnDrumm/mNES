;; maybe a general function for handling each mnemonic is better,
;; with some ifs depending on the mode. hm.

;;set interrupt
alias nes.cpu.mnemonic.sei {

        ;; SEI is always implict
        hadd nes.cpu status.interrupt 1
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
        hadd nes.cpu status.negative $left($base(%byte, 10, 2, 8), 1)

        ;; set zero flag if operand is #$00, else clear it.
        ;; TXS has no operand because it's always implicit, though
        ;; do we just clear it then? or use the value we got from x?
        hadd nes.cpu status.zero 1

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

        ;; always relative

        var %operand $3

        if ($hget(nes.cpu, status.zero) == 1) {

                ;; if the uppermost bit is 1, the value is negative
                if ($left($base(%operand, 10, 2, 8), 1) == 1) {

                        ;; decrement the program counter by the value of the operand
                        hdec nes.cpu programCounter %operand
                }

                else {

                        ;; increment the program counter by the value of the operand
                        hinc nes.cpu programCounter %operand
                }
        }
}

alias -l mergeBytes {

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

;; since stupid. fuckin. starting at 1.
;; yeah. so. here's an alternative that does the extra
;; math for us.
alias -l memWrite {

        bset &RAM $calc($1 + 1) $2
}

alias -l memRead {

        return $bvar(&RAM, $calc($1 + 1))
}

alias nes.cpu.generateOpcodeTable {

        if ($hget(nes.cpu.opcode) != $null) {

                hfree nes.cpu.opcode
        }

        hmake nes.cpu.opcode 256

        echo -s >> generating opcode table...

        ;; file containing list of all ops
        var %file $scriptdir $+ ops.dat

        ;; get total entries in file
        var %t $lines(%file)
        var %i 1

        while (%i <= %t) {

                var %entry $read(%file, %i)
                echo -s adding $read(%file, %i)
                hadd nes.cpu.opcode %entry
                inc %i
        }

        echo -s >> opcode table generated.
}

alias nes.cpu.decodeInstruction {

        var %instruction $hget(nes.cpu.opcode, $1)

        if (%instruction != $null) {

                ;; set mnemonic, byte length, and mode of instruction to $1-
                tokenize 32 %instruction

                var %mnemonic   $1
                var %length     $2
                var %mode       $3
                var %operand    $getOperand($2)

                ;; execute it
                nes.cpu.mnemonic. [ $+ [ %mnemonic ] ] %length %mode %operand

                ;; increment program counter based on instruction length

                return %mnemonic %length %mode %operand
        }

        else {

                return unimplemented
        }
}