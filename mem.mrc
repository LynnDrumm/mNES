;; okay, let's write a stack handler now!! :3

;; add something to the stack

;; complete rewrite
alias nes.mem.stack {

        ;; stack starts at $01FF and decreases down to $0100
        var %startAddress $base(01FF, 16, 10)

        ;; calculate the current stack address.
        ;; start - pointer
        var %stackAddress $calc(%startAddress - $hget(nes.mem, stackPointer))

        var %mode $1

        if (%mode == push) {

                ;; check if we haven't reached stack overflow yet
                if ($hget(nes.mem, stackPointer) < 255) {

                        ;; if pushing, there's a value.
                        var %value $2

                        ;; write value to the stack
                        nes.mem.write %stackAddress %value

                        ;; increment the stack pointer
                        hinc nes.mem stackPointer
                }

                else {

                        echo @nes.debug /!\66,28 $+ $+($chr(160),stack overflow,$chr(160),) $+(96,$calc($ticksqpc - $hget(nes.cpu, ticks.start)),94ms)
                        nes.cpu.stop
                }
        }

        elseif (%mode == pop) {

                ;; read value from the current stack address + 1
                ;; this is what was wrong the whole time. we were reading from
                ;; the *next* stack address, rather than the last one we wrote to.

                ;; big thanks to zowie for talking me through debugging this on discord <3
                var %value $nes.mem.read($calc(%stackAddress + 1))

                ;; decrease stack pointer
                hdec nes.mem stackPointer
        }

        return %value
}

;; since stupid. fuckin. starting at 1.
;; yeah. so. here's an alternative that does the extra math for us.
;; assumes decimal input.
alias nes.mem.write {

        bset &RAM $calc($1 + 1) $2
}

alias nes.mem.read {

        return $bvar(&RAM, $calc($1 + 1))
}

;; we only have one type of memory to save... for now.
alias nes.mem.save {

        if ($1 == RAM) {

                hadd -b nes.mem RAM &RAM
        }
}

alias nes.mem.init {

        ;; set up RAM. just fill it with zeroes first.
        echo @nes.debug setting up RAM

        if ($hget(nes.mem) != $null) {

                hfree nes.mem
        }

        hmake nes.mem 10

        bset &RAM $calc(64 * 1024) 0

        ;; stack is 256 bytes from $0100 - $01FF.
        ;; it starts at $01FF and is filled from there, backwards.
        hadd nes.mem stackPointer 0
}