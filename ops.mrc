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

;; clear carry flag
alias nes.cpu.mnemonic.clc {

        ;; always implicit
        hadd nes.cpu status.carry 0
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

                var %result $nes.mem.read($mergeBytes(%operand))
        }

        elseif (%mode == zeropage) {

                var %result $nes.mem.read(%operand)
        }

        ;; store result in accumulator
        hadd nes.cpu accumulator %result

        ;; set negative flag is bit 7 is set
        hadd nes.cpu status.negative $getBit(%result, 7)

        ;; set zero flag if operand is #$00
        hadd nes.cpu status.zero $iif(%result == 0, 1, 0)

        return %result
}

;; store accumulator
alias nes.cpu.mnemonic.sta {

        var %length     $1
        var %mode       $2
        var %operand    $3-

        if (%mode == absolute) {

                var %address $mergeBytes(%operand)
        }

        elseif (%mode == indirect,y) {

                var %address $calc($nes.mem.read(%operand) + $hget(nes.cpu, y))
        }

        elseif (%mode == zeropage) {

                var %address %operand
        }

        nes.mem.write %address $hget(nes.cpu, accumulator)

        return %address
}

;; push accumulator to stack
alias nes.cpu.mnemonic.pha {

        nes.mem.stack push $hget(nes.cpu, accumulator)
}

;; LoaD X index with memory
alias nes.cpu.mnemonic.ldx {

        var %length     $1
        var %mode       $2
        var %operand    $3

        if (%mode == immediate) {

                var %result %operand
        }

        ;; set x register to result
        hadd nes.cpu x %result

        ;; set negative flag equal to the 7th bit,
        ;; i assume of the operand?
        hadd nes.cpu status.negative $getBit(%result, 7)

        ;; set zero flag if operand is #$00, else clear it.
        hadd nes.cpu status.zero $iif(%result == 0, 1, 0)

        return %result
}

;; transfer X to accumulator
alias nes.cpu.mnemonic.txa {

        var %value $hget(nes.cpu, x)

        ;; write contents of x to accumulator
        hadd nes.cpu accumulator %value

        ;; set negative flag if bit 7 of the accumulator is set
        hadd nes.cpu status.negative $getBit(%value, 7)

        ;; set zero flag if accumulator is now 0
        hadd nes.cpu status.zero $iif(%value == 0, 1, 0)
}

;; transfer accumulator to X
alias nes.cpu.mnemonic.tax {

        var %value $hget(nes.cpu, accumulator)

        ;; write contents of accumulator to x
        hadd nes.cpu x %value

        ;; set negative flag if bit 7 of x is set
        hadd nes.cpu status.negative $getBit(%value, 7)

        ;; set zero flag if x is now 0
        hadd nes.cpu status.zero $iif(%value == 0, 1, 0)
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
        nes.mem.stack push %value
}

;; load y index with memory
alias nes.cpu.mnemonic.ldy {

        var %length     $1
        var %mode       $2
        var %operand    $3

        if (%mode == immediate) {

                var %result %operand
        }

        ;; set y register to result
        hadd nes.cpu y %result

        ; clear negative flag if operand is #$00 - #$7F, else set it.
        hadd nes.cpu status.negative $iif(%result <= 127, 0, 1)

        ;; set zero flag if operand is #$00
        hadd nes.cpu status.zero $iif(%result == 0, 1, 0)

        return %result
}

;; store value of y to location
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
        nes.mem.write %address $hget(nes.cpu, y)

        return %address
}

;; decrement y register
alias nes.cpu.mnemonic.dey {

        ;; mode is always implied

        ;; decrement y register
        hdec nes.cpu y

        if ($hget(nes.cpu, y) < 0) {

                hadd nes.cpu y $dec(ff)
        }

        ;; set negative flag if bit 7 is set
        hadd nes.cpu status.negative $getBit($hget(nes.cpu, y), 7)

        ;; set zero flag if operand is #$00
        hadd nes.cpu status.zero $iif($hget(nes.cpu, y) == 0, 1, 0)
}

;; transfer y to accumulator
alias nes.cpu.mnemonic.tya {

        var %value $hget(nes.cpu, y)

        hadd nes.cpu accumulator %value

                ;; set negative flag if bit 7 of the accumulator is set
        hadd nes.cpu status.negative $getBit(%value, 7)

        ;; set zero flag if accumulator is now 0
        hadd nes.cpu status.zero $iif(%value == 0, 1, 0)
}

;; Logical AND memory with accumulator
alias nes.cpu.mnemonic.and {

        var %length     $1
        var %mode       $2
        var %operand    $3

        var %accumulator $hget(nes.cpu, accumulator)

        if (%mode == immediate) {

                var %value %operand

        }

        elseif (%mode == zeropage) {

                ;; get value from zeropage
                var %value $nes.mem.read(%operand)
        }

        ;; logical AND between operand and accumulator
        ;; 6502.org says bit by bit, so... let's try that?

        var %i 0

        while (%i < 8) {

                var %and $and($getBit(%value, %i), $getBit(%accumulator, %i))

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

        ;; push the result to the accumulator
        hadd nes.cpu accumulator %result

        ;; set negative flag equal to the 7th bit.
        ;; of the operand, or the result?
        hadd nes.cpu status.negative $getBit(%result, 7)

        ;; set zero flag if operand is #$00, else clear it.
        hadd nes.cpu status.zero $iif(%result == 0, 1, 0)
}

;; compare contents of accumulator with another value
alias nes.cpu.mnemonic.cmp {

        var %mode       $2
        var %operand    $3-

        if (%mode == immediate) {

                var %value %operand
        }

        var %result $calc(%$hget(nes.cpu, accumulator) - %value)

        hadd nes.cpu status.carry    $iif(%accumulator >= %value, 1, 0)
        hadd nes.cpu status.zero     $iif(%accumulator == %value, 1, 0)

        ;; negative flag is set if the 7th bit of the result is set.
        hadd nes.cpu status.negative $getBit(%result, 7)
}

;; add with carry
alias nes.cpu.mnemonic.adc {

        var %mode        $2
        var %operand     $3-
        var %accumulator $hget(nes.cpu, accumulator)

        if (%mode == zeropage) {

                var %value $nes.mem.read(%operand)
        }

        ;; i'm so incredibly grateful for everyone who has patiently
        ;; helped me and explained stuff ❤ special shoutout to
        ;; TheMogMiner for this one:

        ;; add accumulator + value... plus the carry bit? somehow?
        ;; ...maybe i don't understand just yet...
        var %value      $calc(%value + $hget(nes.cpu, status.carry))
        var %result     $calc(%accumulator + %value)

        ;; if >255, loop around, and set the carry flag
        if (%result > 255) {

                ;; loop result around
                var %result $calc(%result - 255)

                ;; set carry flag
                hadd nes.cpu status.carry 1
        }

        else {

                ;; always gotta unset things if any condition
                ;; that sets a flag isn't met.
                hadd nes.cpu status.carry 0
        }

        ;; compare bit 7 of accu and value.
        if ($getBit(%accumulator, 7) == $getBit(%value, 7)) {

                ;; if identical, we check if bit 7 of the result is different
                if ($getBit(%accumulator, 7) != $getBit(%result, 7)) {

                        ;; set overflow flag if bit 7 of accu and result are different
                        hadd nes.cpu status.overflow 1
                }

                else {

                        hadd nes.cpu status.overflow 0
                }
        }

        else {

                hadd nes.cpu status.overflow 0
        }
}

;; logical shift right
alias nes.cpu.mnemonic.lsr {

        var %mode       $2
        var %operand    $3-

        ;; lowest bit is shifted into the carry flag,
        ;; highest bit is set to 0

        if (%mode == accumulator) {

                var %value $bin($hget(nes.cpu, accumulator))
        }

        ;; get the bit to shift into the carry flag
        var %carry $right($bin(%value), 1)

        ;; get leftmost 7 bits (strip lowest bit),
        ;; and stick 0 in front of it.
        ;; yeaaaaaaaah
        var %result $dec($+(0,$left(%value, 7))).bin

        ;; i can't think of a better way to do this right now
        if (%mode == accumulator) {

                hadd nes.cpu accumulator %result
        }

        ;; set status flags
        hadd nes.cpu status.carry    %carry
        hadd nes.cpu status.zero     $iif(%result == 0, 1, 0)
        hadd nes.cpu status.negative $getBit(%result, 7)

}

;; branch if equal
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
        var %sign $iif($getBit(%operand, 7) == 1, -, +)

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

;; branch if not equal
alias nes.cpu.mnemonic.bne {

        ;; most of this is like `beq` above.

        ;; mode is always relative
        var %operand $3

        ;; get sign to determine branching forward or backward
        var %sign $iif($getBit(%operand, 7) == 1, -, +)

        ;; two's complement, condensed!
        var %value $calc($dec($invert($bin(%operand))).bin + 1)

        ;; interpreter abuse, as above
        var %result $calc($hget(nes.cpu, programCounter) %sign %value)

        if ($hget(nes.cpu, status.zero) == 0) {

                hadd nes.cpu programCounter %result
        }

        return $calc(%result + 1)
}

;; branch if positive
alias nes.cpu.mnemonic.bpl {

        ;; mode is always relative
        var %operand $3

        ;; get sign to determine branching forward or backward
        var %sign $iif($getBit(%operand, 7) == 1, -, +)

        ;; two's complement, condensed!
        var %value $calc($dec($invert($bin(%operand))).bin + 1)

        ;; interpreter abuse, as above
        var %result $calc($hget(nes.cpu, programCounter) %sign %value)

        if ($hget(nes.cpu, status.negative) == 0) {

                hadd nes.cpu.programCounter %result
        }

        return %result
}

alias nes.cpu.mnemonic.jmp {

        var %mode       $2
        var %operand    $3-

        if (%mode == absolute) {

                ;; subtract 1 from target address so we actually end up
                ;; in the right place...
                var %address $calc($mergeBytes(%operand) - 1)
        }

        hadd nes.cpu programCounter %address

        return %address
}

alias nes.cpu.mnemonic.jsr {

        ;; mode is always absolute
        var %operand $3-

        var %address $mergeBytes(%operand)

        ;; calculate the return point.
        ;; this should be the current value of the program counter, minus a few.
        ;; Everywhere I'm reading it says it should be -1, but I'm having doubts.
        ;; the program counter, at this point, is increased by operand length,
        ;; mainly because that's what various sources led me to believe.
        ;; so if we subtract 1, we would point back to the 2nd byte of the
        ;; operand... which... actually makes sense, because next cycle we
        ;; increment the program counter again and end up at the next instruction!

        ;; ...thanks for listening, sometimes you just gotta talk through
        ;; a problem to figure it out ^-^

        var %returnAddress $calc($hget(nes.cpu, programCounter) - 1)

        ;; now we push this to the stack. i think i'll just let my stack functions
        ;; handle 16-bit values, saves me the trouble of fixing things in multiple
        ;; places later on when I fuck up the byte order or something.
        nes.mem.stack push %returnAddress

        ;; and now we set the program counter to our target address!
        ;; we do gotta subtract 1 tho. stubid off by one errors...
        hadd nes.cpu programCounter $calc(%address - 1)

        return %address
}

alias nes.cpu.mnemonic.brk {

        ;; mode is always implicit

        ;; push program counter onto the stack
        nes.mem.stack push $hget(nes.cpu, programCounter)

        ;; push processor status onto the stack...
        nes.mem.stack push $dec($nes.cpu.statusFlags).bin

        ;; get IRQ interrupt vector at $FFFE-$FFFF
        var %lower $hex($nes.mem.read($dec(FFFE)))
        var %upper $hex($nes.mem.read($dec(FFFF)))
        var %address $+(%upper,%lower)

        hadd nes.cpu programCounter $dec(%address)

        hadd nes.cpu status.break 1
}

alias nes.cpu.mnemonic.dec {

        var %mode       $2
        var %operand    $3

        if (%mode == zeropage) {

                var %address    %operand
                var %value      $calc($nes.mem.read(%address) - 1)

                if (%value < 0) {

                        var %value $dec(ff)
                }

                nes.mem.write %address %value

                ;; set negative flag equal to the 7th bit of the result
                hadd nes.cpu status.negative $getBit(%result, 7)

                ;; set zero flag if result is #$00, else clear it.
                hadd nes.cpu status.zero $iif(%result == 0, 1, 0)
        }

        return %value
}

;; -----------------------------------------------------------------------------------------------------------------------------------


;; gets the $2-th bit of the byte in $1

;; ...talk shit...
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

