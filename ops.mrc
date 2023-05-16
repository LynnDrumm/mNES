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
        var %operand    $3-

        if (%mode == immediate) {

                var %result %operand
        }

        elseif (%mode == absolute) {

                var %result $nes.ram.read($mergeBytes(%operand))
        }

        ;; set negative flag is bit 7 is set
        hadd nes.cpu status.negative $getBit(%result, 7)

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

        nes.ram.write %address $hget(nes.cpu, accumulator)
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
        hadd nes.cpu status.negative $getBit(%operand, 7)

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
        hadd nes.cpu status.negative $getBit(%value, 7)

        ;; store the value of X into the stack
        nes.ram.write $hget(nes.cpu, stackPointer) $hget(nes.cpu, x)

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
        nes.ram.write %address $hget(nes.cpu, y)
}

;; Logical AND memory with accumulator
alias nes.cpu.mnemonic.and {

        var %length     $1
        var %mode       $2
        var %operand    $3

        if (%mode == immediate) {

                ;; logical AND between operand and accumulator
                ;; 6502.org says bit by bit, so... let's try that?

                var %i 0
                var %accumulator $hget(nes.cpu, accumulator)

                ;echo -s o: $bin(%operand)
                ;echo -s a: $bin(%accumulator)

                while (%i < 8) {

                        var %a $getBit(%operand, %i)
                        var %b $getBit(%accumulator, %i)
                        var %and $and(%a, %b)

                        ;echo -s > %a AND %b = %and

                        var %result $+(%and,%result)
                        inc %i
                }

                ;; not entirely convinced the above does anything different
                ;; than just straight using $and() on the operand/accu,
                ;; so uncomment this line to double check in the future.
                ;echo -s . %operand AND %accumulator = $and(%operand, %accumulator)

                ;; convert result back to decimal
                ;echo -s b: %result d: $dec(%result).bin h: $hex($dec(%result).bin)
                var %result $dec(%result).bin
        }

        ;; set negative flag equal to the 7th bit.
        ;; of the operand, or the result?
        hadd nes.cpu status.negative $getBit(%result, 7)

        ;; set zero flag if operand is #$00, else clear it.
        hadd nes.cpu status.zero $iif(%result == 0, 1, 0)

        ;; push the result to the accumulator
        hadd nes.cpu accumulator %result
}

alias nes.cpu.mnemonic.beq {

        ;; wrong. it's wrong. it's all wrong.
        ;; aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
        ;; *stabs brain with fork*

        ;; mode is always relative
        var %operand $3

        ;; i've been doing this completely wrong. oops.
        ;; look at https://twitter.com/kebby/status/1658532782803410946
        ;; and https://www.cs.cornell.edu/~tomf/notes/cps104/twoscomp.html

        ;; signed bytes use the most significant bit (7) as the sign
        ;; if 0, it's a negative number, and if 1, positive.
        ;; we'll prepare for some mIRC interpreter abuse later
        ;; by setting %sign to either - or + depending on the result,
        ;; which we can then just feed into $calc(), which will
        ;; happily be interpreted as the correct mathmetical operator.
        var %sign $iif($getBit(%operand) == 1, -, +)

        ;; two's complement
        ;; we'll make the value binary
        var %value      $bin(%operand)
        ;; invert the bits
        var %value     $invert(%value)
        ;; and add 1 to get the result
        var %value     $calc($dec(%value).bin + 1)

        ;; here comes the interpreter abuse! since variables and everything
        ;; are evaluated first, %sign will just become - or +, and $calc()
        ;; will just accept this and perform our desired operation.
        var %result $calc($hget(nes.cpu, programCounter) %sign %value)

        ;; branch only if the Zero flag of the status register is 1
        if ($hget(nes.cpu, status.zero) == 1) {

                hadd nes.cpu programCounter %result
        }

        ;; add 1 to the output result for display purposes.
        ;; the actually calculated value is correct, setting the program
        ;; counter 1 before the desired branch address, which it will
        ;; be set to as soon as the CPU loop restarts
        return $calc(%result + 1)
}

;; -----------------------------------------------------------------------------------------------------------------------------------

;; gets the $2-th bit of the byte in $1
alias -l getBit {

        ;; since mIRC starts from 1 with most things, we'll add 1
        ;; to the specified bit, and force it to be a negative value.
        ;; this way we can just call $getBit(byte, 0) to get the
        ;; least significant (rightmost) bit, and 7 will give us the
        ;; most significant (leftmost) bit!
        return $mid($bin($1), $+(-,$calc($2 + 1)), 1)
}


;; converts input bytes from decimal to hex,
;; and fuses them together (2 8-bit -> 1 16-bit value)
alias -l mergeBytes {

        tokenize 32 $1-

        ;; for reasons that are beyond my tiny cat brain,
        ;; the byte order is swapped.
        return $dec($+($hex($2),$hex($1)))
}

;; inverts a byte. expects binary. returns binary.
alias -l invert {

        return $right($base($not($base($1, 2, 10)), 10, 2), 8)
}

;; these things below are getting messy.
;; i wanted to use them for readability, since $base()
;; everywhere was feeling clunky, but maybe i need to
;; reconsider...

;; explicit hex -> decimal conversion
;; .bin for conversaion from binary
alias -l dec {

        return $base($1, $iif($prop == bin, 2, 16), 10)
}

;; explicit decimal -> hex conversion. always padded to 2 digits.
alias -l hex {

        return $base($1, 10, 16, 2)
}

;; explicit decimal -> binary conversion.
;; always returns all 8 bits, even if leading ones are 0.
alias -l bin {

        return $base($1, 10, 2, 8)
}

;; since stupid. fuckin. starting at 1.
;; yeah. so. here's an alternative that does the extra
;; math for us.
;; assumes decimal input
alias nes.ram.write {

        bset &RAM $calc($1 + 1) $2
}

alias nes.ram.read {

        return $bvar(&RAM, $calc($1 + 1))
}