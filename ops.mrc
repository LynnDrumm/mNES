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
        var %operand    $3

        if (%mode == immediate) {

                var %result %operand
        }

        elseif (%mode == absolute) {

                ;; operand is 2 bytes, so let's grab them both.
                var %operand    $3-
                var %result     $nes.mem.read($mergeBytes(%operand))
        }

        elseif (%mode == zeropage) {

                var %result $nes.mem.read(%operand)
        }

        elseif (%mode == indirect,y) {

                ;; get lower byte of address from zeropage
                var %addressLower $hex($nes.mem.read(%operand))

                ;; get higher byte of address from consecutive zeropage address
                ;; if crossing zeropage address ff, loop back around.
                if (%operand < 255) {

                        var %addressHigher $hex($nes.mem.read(%operand + 1))
                }

                else {

                        var %addressHigher $hex($nes.mem.read(0))
                }

                ;; combine higher/lower, add y index, that is our target address.
                var %address $calc($dec($+(%addressHigher,%addressLower)) + $hget(nes.cpu, y))

                ;; loop back to $0000 if crossing $ffff
                if (%address > $hex(ffff)) {

                        var %address $calc(%address - $hex(ffff))
                }

                ;; get value from address
                var %result $nes.mem.read(%address)
        }

        ;; store result in accumulator
        hadd nes.cpu accumulator %result

        setFlag zero     $hget(nes.cpu, accumulator)
        setFlag negative $hget(nes.cpu, accumulator)

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

                ;; get lower byte of address from zeropage
                var %addressLower $hex($nes.mem.read(%operand))

                ;; get higher byte of address from consecutive zeropage address
                ;; if crossing zeropage address ff, loop back around.
                if (%operand < 255) {

                        var %addressHigher $hex($nes.mem.read(%operand + 1))
                }

                else {

                        var %addressHigher $hex($nes.mem.read(0))
                }

                ;; combine higher/lower, add y index, that is our target address.
                var %address $calc($dec($+(%addressHigher,%addressLower)) + $hget(nes.cpu, y))

                ;; loop back to $0000 if crossing $ffff
                if (%address > $hex(ffff)) {

                        var %address $calc(%address - $hex(ffff))
                }
        }

        elseif (%mode == zeropage) {

                var %address %operand
        }

        elseif (%mode == absolute,x) {

                var %address $calc($mergeBytes(%operand) + $hget(nes.cpu, x))

                ;; handle overflow
                if (%address > $dec(ffff)) {

                        var %address $calc(%address - $dec(ffff))
                }
        }

        nes.mem.write %address $hget(nes.cpu, accumulator)

        return %address
}

;; push accumulator to stack
alias nes.cpu.mnemonic.pha {

        nes.mem.stack push $hget(nes.cpu, accumulator)
}

;; pull accu from stack
alias nes.cpu.mnemonic.pla {

        hadd nes.cpu accumulator $nes.mem.stack(pop)
}

;; LoaD X index with memory
alias nes.cpu.mnemonic.ldx {

        var %length     $1
        var %mode       $2
        var %operand    $3

        if (%mode == immediate) {

                var %result %operand
        }

        elseif (%mode == absolute) {

                var %address $mergeBytes(%operand)
                var %result  $nes.mem.read(%address)
        }

        ;; set x register to result
        hadd nes.cpu x %result

        setFlag zero     %result
        setFlag negative %result

        return %result
}

;; transfer X to accumulator
alias nes.cpu.mnemonic.txa {

        var %value $hget(nes.cpu, x)

        ;; write contents of x to accumulator
        hadd nes.cpu accumulator %value

        setFlag zero     $hget(nes.cpu, accumulator)
        setFlag negative $hget(nes.cpu, accumulator)
}

;; transfer accumulator to X
alias nes.cpu.mnemonic.tax {

        var %value $hget(nes.cpu, accumulator)

        ;; write contents of accumulator to x
        hadd nes.cpu x %value

        setFlag zero     $hget(nes.cpu, accumulator)
        setFlag negative $hget(nes.cpu, accumulator)
}

;;Transfer X to Stack
alias nes.cpu.mnemonic.txs {

        ;; store the value in X to the stack
        nes.mem.stack push $hget(nes.cpu, x)
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

        setFlag zero     $hget(nes.cpu, y)
        setFlag negative $hget(nes.cpu, y)

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

;; increment y register
alias nes.cpu.mnemonic.iny {

        hinc nes.cpu y

        ;; if y is now less than 0, roll back over to $ff
        if ($hget(nes.cpu, y) > 255) {

                hadd nes.cpu y 0
        }

        setFlag zero     $hget(nes.cpu, y)
        setFlag negative $hget(nes.cpu, y)
}


;; decrement y register
alias nes.cpu.mnemonic.dey {

        hdec nes.cpu y

        ;; if y is now less than 0, roll back over to $ff
        if ($hget(nes.cpu, y) < 0) {

                hadd nes.cpu y $dec(ff)
        }

        setFlag zero     $hget(nes.cpu, y)
        setFlag negative $hget(nes.cpu, y)
}

;; increment x register
alias nes.cpu.mnemonic.inx {

        hinc nes.cpu x

        ;; if x is now less than 0, roll back over to $ff
        if ($hget(nes.cpu, x) > 255) {

                hadd nes.cpu x 0
        }

        setFlag zero     $hget(nes.cpu, x)
        setFlag negative $hget(nes.cpu, x)
}


;; decrement x register
alias nes.cpu.mnemonic.dex {

        hdec nes.cpu x

        if ($hget(nes.cpu, x) < 0) {

                hadd nes.cpu x $dec(ff)
        }

        setFlag zero     $hget(nes.cpu, x)
        setFlag negative $hget(nes.cpu, x)
}

;; transfer y to accumulator
alias nes.cpu.mnemonic.tya {

        var %value $hget(nes.cpu, y)

        hadd nes.cpu accumulator %value

        setFlag zero     $hget(nes.cpu, y)
        setFlag negative $hget(nes.cpu, y)
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

        setFlag zero     $hget(nes.cpu, accumulator)
        setFlag negative $hget(nes.cpu, accumulator)
}

;; compare contents of accumulator with another value
alias nes.cpu.mnemonic.cmp {

        var %mode       $2
        var %operand    $3

        if (%mode == immediate) {

                var %value %operand
        }

        var %result $calc($hget(nes.cpu, accumulator) - %value)

        ;; set zero flag on "equal" comparison (i.e., both accu and
        ;; operand are the same value and result is 0)
        setFlag zero     %result
        ;; negative flag is set if bit 7 is set
        setFlag negative %result

        ;; carry is set if value is <= to accumulator,
        ;; reset if greater than.
        ;; hardcoded for now until I'm sure I can re-use
        ;; this code for other instructions
        if (%result <= $hget(nes.cpu, accumulator)) {

                hadd nes.cpu status.carry 1
        }

        else {

                hadd nes.cpu status.carry 0
        }
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

        setFlag negative
}

;; ROtate Right
alias nes.cpu.mnemonic.ror {

        var %mode $2

        if (%mode == accumulator) {

                var %value $hget(nes.cpu, accumulator)
        }

        ;; get bit 0
        var %bit0 $getbit(%value, 0)

        ;; get carry
        var %carry $hget(nes.cpu, status.carry)

        ;; result is all bits shifted 1 place right,
        ;; bit 7 is set to current value of carry.
        var %result $dec($+(%carry,$left(%value, 7))).bin

        ;; set N flag to "input carry". like this?
        hadd nes.cpu status.negative $hget(nes.cpu, status.carry)
        ;; set carry to previous value of bit 0
        hadd nes.cpu status.carry %bit0

        if (%result == 0) {

                hadd nes.cpu status.zero 1
        }

        else {

                hadd nes.cpu status.zero 0
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
        setFlag zero %result
        ;; negative flag is always set to 0
        hadd nes.cpu status.negative 0
        hadd nes.cpu status.carry    %carry

}

alias nes.cpu.mnemonic.asl {

        var %mode $2
        var %operand $3

        if (%mode == zeropage) {

                var %address %operand

                var %value $nes.mem.read(%address)
        }

        if (%mode == accumulator) {

                var %value $hget(nes.cpu, accumulator)
        }

        var %bit7 $left($bin(%value), 1)

        var %result $dec($+($right(%value, 7),0)).bin

        hadd nes.cpu status.carry %bit7
        hadd nes.cpu status.negative %bit7
        setFlag zero %result


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
        ;var %value $calc($dec($invert($bin(%operand))).bin + 1)
        ;; above line used $invert, which is a function i wrote (find it lower
        ;; in this file...) -- it seemed a bit silly though, but...
        ;; $not returns a 32-bit value, i don't know how to cull it
        ;; apart from converting from decimal to binary, then keeping
        ;; only the rightmost 8 bits and converting that back to decimal...
        ;; so this isn't really much better at all.
        var %value $calc($base($right($base($not(%operand), 10, 2), 8), 2, 10) + 1)

        ;; interpreter abuse, as above
        var %result $calc($hget(nes.cpu, programCounter) %sign %value)

        if ($hget(nes.cpu, status.zero) == 0) {

                hadd nes.cpu programCounter %result
        }

        ;; add 1 to the output result for display purposes.
        ;; the actually calculated value is correct, setting the program
        ;; counter 1 before the desired branch address, which it will
        ;; be set to as soon as the CPU loop restarts
        return $calc(%result + 1)
}

;; branch if carry set
alias nes.cpu.mnemonic.bcs {

        var %operand $3

        ;; get sign to determine branching forward or backward
        var %sign $iif($getBit(%operand, 7) == 1, -, +)

        ;; two's complement, condensed!
        var %value $calc($dec($invert($bin(%operand))).bin + 1)

        ;; interpreter abuse, as above
        var %result $calc($hget(nes.cpu, programCounter) %sign %value)

        if ($hget(nes.cpu, status.carry) == 1) {

                hadd nes.cpu programCounter %result
        }

        ;; add 1 to the output result for display purposes.
        ;; the actually calculated value is correct, setting the program
        ;; counter 1 before the desired branch address, which it will
        ;; be set to as soon as the CPU loop restarts
        return $calc(%result + 1)
}

;; branch on carry clear
alias nes.cpu.mnemonic.bcc {

        var %operand $3

        ;; get sign to determine branching forward or backward
        var %sign $iif($getBit(%operand, 7) == 1, -, +)

        ;; two's complement, condensed!
        var %value $calc($dec($invert($bin(%operand))).bin + 1)

        ;; interpreter abuse, as above
        var %result $calc($hget(nes.cpu, programCounter) %sign %value)

        if ($hget(nes.cpu, status.carry) == 0) {

                hadd nes.cpu programCounter %result
        }

        ;; add 1 to the output result for display purposes.
        ;; the actually calculated value is correct, setting the program
        ;; counter 1 before the desired branch address, which it will
        ;; be set to as soon as the CPU loop restarts
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

                hadd nes.cpu programCounter %result
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

;; Jump to SubRoutine
alias nes.cpu.mnemonic.jsr {

        echo -s 56 JSR

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

        var %returnAddress $base($calc($hget(nes.cpu, programCounter) - 1), 10, 16, 4)

        ;; split into upper / lower byte
        var %upper $dec($left(%returnAddress, 2))
        var %lower $dec($right(%returnAddress, 2))

        ;; now we push this to the stack.
        echo -s . nes.mem.stack push %upper
        nes.mem.stack push %upper
        echo -s . nes.mem.stack push %upper
        nes.mem.stack push %lower

        echo -s . jsr return: %returnAddress

        ;; and now we set the program counter to our target address!
        ;; we do gotta subtract 1 tho. stubid off by one errors...
        hadd nes.cpu programCounter $calc(%address - 1)

        return %address
}

;; ReTurn from Subroutine
alias nes.cpu.mnemonic.rts {

        echo -s 52 RTS

        ;; get topmost 2 values from the stack, that is the return address.
        ;; i love how incredibly cursed this is. if you performed an odd
        ;; number of push/pop operations in between a jsr and rts, you have
        ;; essentially modified the return address, which means you could
        ;; theoretically abuse this to jump anywhere in memory.
        ;; ...why you would do that over just a plain jmp, i don't know.
        var %lower $hex($nes.mem.stack(pop))
        echo -s . lower: %lower
        var %upper $hex($nes.mem.stack(pop))
        echo -s . upper: %upper
        var %returnAddress $dec($+(%upper,%lower))
        echo -s . RTS return: $hex(%returnAddress)

        hadd nes.cpu programCounter %returnAddress
}

alias nes.cpu.mnemonic.brk {

        ;; mode is always implicit

        ;; push program counter onto the stack
        ;nes.mem.stack push $hget(nes.cpu, programCounter)

        ;; push processor status onto the stack...
        ;nes.mem.stack push $dec($nes.cpu.statusFlags).bin

        ;; get IRQ interrupt vector at $FFFE-$FFFF
        ;var %lower $hex($nes.mem.read($dec(FFFE)))
        ;var %upper $hex($nes.mem.read($dec(FFFF)))
        ;var %address $+(%upper,%lower)

        ;hadd nes.cpu programCounter $dec(%address)

        hadd nes.cpu status.break 1
}

alias nes.cpu.mnemonic.inc {

        var %mode       $2
        var %operand    $3

        if (%mode == zeropage) {

                var %address %operand
                var %result     $calc($nes.mem.read(%address) + 1)

                if (%result > 255) {

                        var %result 0
                }

                nes.mem.write %address %result
        }

        setFlag zero     %result
        setFlag negative %result

        return %result
}

alias nes.cpu.mnemonic.dec {

        var %mode       $2
        var %operand    $3

        if (%mode == zeropage) {

                var %address    %operand
                var %result     $calc($nes.mem.read(%address) - 1)

                if (%result < 0) {

                        var %result 255
                }

                nes.mem.write %address %result
        }

        setFlag zero     %result
        setFlag negative %result

        return %result
}

alias nes.cpu.mnemonic.ora {

        var %mode       $2
        var %operand    $3

        if (%mode == immediate) {

                var %value %operand
        }

        ;; binary OR

        var %accumulator $bin($hget(nes.cpu, accumulator))
        var %value       $bin(%value)

        var %result     $or(%accumulator, %value)

        ;; store result in accumulator
        hadd nes.cpu accumulator $dec(%result).bin

        setFlag zero     $hget(nes.cpu, accumulator)
        setFlag negative $hget(nes.cpu, accumulator)
}

;; -----------------------------------------------------------------------------------------------------------------------------------

;; sets $1 flag based on $2 input
alias -l setFlag {

        if ($1 == zero) {

                ;; sets zero flag is input is 0
                if ($2 == 0) {

                        hadd nes.cpu status.zero 1
                }

                else {

                        hadd nes.cpu status.zero 0
                }
        }

        elseif ($1 == negative) {

                ;; sets negative flag if bit 7 of input is 1
                if ($2 > 127) {

                        hadd nes.cpu status.negative 1
                }

                else {

                        hadd nes.cpu status.negative 0
                }
        }
}

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

