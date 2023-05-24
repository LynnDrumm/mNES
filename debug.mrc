alias nes.debug.cpu {

        var %cycles     $+(72,$padstring(6, $hget(nes.cpu, cycles)).pre)
        var %pc         $+(41$,65,$base($1, 10, 16, 4))
        var %opcode     $+(4468,$2)
        var %length     $3

        ;; instructions are at least 1 byte long.
        ;; if not, well, it's just not implemented yet!
        if (%length > 0) {

                if ($hget(nes.cpu, debug) == full) {

                        var %mode       $4
                        var %mnemonic   $5

                        ;; special handling for how to display the operand/result depending on length/mode
                        if (%mode == implicit) {

                                ;; since implicit instructions have no operand or "result",
                                var %result %operand
                        }

                        elseif (%mode == immediate) {

                                ;; immediate mode means the operand is a single byte direct value,
                                ;; to be prefixed with #$, not to be confused with zeropage, which
                                ;; is also a single byte operand but is displayed as an 8-bit address.
                                var %operand $+(57,$base($6, 10, 16, 2))
                                var %result $+(50#$,74,$base($6, 10, 16, 2))

                        }

                        elseif (%mode == absolute) {

                                ;; this is an address. for display purposes, swap them bytes again.
                                var %operand $+(57,$base($6, 10, 16, 2)) $+(69,$base($7, 10, 16, 2))
                                var %result $+(50$,74,$+($hex($7),$hex($6)))
                        }

                        elseif (%mode == relative) {

                                ;; if mode is relative, we'd rather display the result of the
                                ;; instruction, so we can see where a branch ends up,
                                ;; rather than the offset we may or not be adding/subtracting.

                                ;; we're still keeping the original operand as well though,
                                ;; just to keep things clear
                                var %operand $+(57,$base($6, 10, 16, 2))
                                var %result $+(50$,74,$base($7, 10, 16, 4))
                        }

                        elseif (%mode == zeropage) {

                                ;; operands on single page operations are only 1 byte long.
                                var %operand $+(57,$base($6, 10, 16, 2))
                                var %result $+(50$,74,$base($6, 10, 16, 2))
                        }

                        elseif (%mode == indirect,y) {

                                ;; this is an address. for display purposes, swap them bytes again.
                                var %operand $+(57,$base($6, 10, 16, 2))
                                var %result $+(50$,74,$base($7, 10, 16, 4),50,$chr(44),74,$hex($hget(nes.cpu, y)))
                        }

                        ;; calculate n prettify execution time
                        var %ticks $+(96,$calc($ticksqpc - $hget(nes.cpu, ticks.instruction)),94ms) 91/ $+(96,$calc($ticksqpc - $hget(nes.cpu, ticks.start)),94ms91,$chr(44),96) $hget(nes.cpu, ips) 94ips

                        ;; prettify the status flag display
                        var %flags $replace($nes.cpu.statusFlags, 0, $+(30,0), 1, $+(66,1))

                        var %regs 85 $padString(2, $hex($hget(nes.cpu, accumulator))) $padString(2, $hex($hget(nes.cpu, x))) $padString(2, $hex($hget(nes.cpu, y)))

                        ;; the big line that put da stuff on screen~
                        ;; this is getting a bit unwieldy, lol
                        iline @nes.debug $line(@nes.debug, -1) %cycles %pc 93: %opcode $padString(5, %operand) 93-> $+(71,%mnemonic) $padString(8, %result) $padString(10, %regs) $padString(11, $+(94,%mode)) $padString(10, %flags) %ticks
                        ;echo @nes.debug %cycles %pc 93: %opcode $padString(5, %operand) 93-> $+(71,%mnemonic) $padString(6, %result) $padString(10, %regs) $padString(11, $+(94,%mode)) $padString(10, %flags) %ticks
                }
        }

        else {

                ;; print a warning if we encounter an unimplemented opcode
                echo @nes.debug %cycles %pc 93: %opcode $padString(5, %operand) 93-> 54,52 $+ /!\66,28 $+ $+($chr(160),unimplemented instruction,$chr(160),) $+(96,$calc($ticksqpc - $hget(nes.cpu, ticks.start)),94ms)
        }
}

alias nes.debug.init {

        ;; debug output selector.
        ;; full shows everything, error only shows errors, none shows... none!
        ;; this is not completely implemented but it's a start
        hadd nes.cpu debug $iif($1, $1, error)

        if ($hget(nes.cpu, debug) == full) {

                ;; print debug header, twice. this is because our cpu output
                ;; gets printed right in between, so that it's easier to read
                ;; the output even if we're all the way at the end.
                debugHeader
                debugHeader
        }
}

alias -l debugHeader {

        echo @nes.debug 91---95cyl91-95pc91------95op91-95oprnd91----95mnm91-95result91----95A91--95X91--95Y91----95mode91--------95NVssDIZC91---95exec91--95real91------------
}

;; pad $2- up to $1 characters, using $chr(160) ((unicode space))
alias -l padString {

        var %stringLength       $len($strip($2-))
        var %newLength          $1
        var %padLength          $calc(%newLength - %stringLength)
        var %padding            $str($chr(160),%padLength)

        return $iif($prop == pre, $+(%padding,$2-), $+($2-,%padding))
}


;; explicit hex -> decimal conversion
alias -l dec {

        return $base($1, 16, 10)
}

;; explicit decimal -> hex conversion
alias -l hex {

        return $base($1, 10, 16, 2)
}