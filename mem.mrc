;; okay, let's write a stack handler now!! :3

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

        echo -s . $time : stack $1 -> $base(%value, 10, 16)

        return %value
}

;; since stupid. fuckin. starting at 1.
;; yeah. so. here's an alternative that does the extra math for us.
;; assumes decimal input.
alias nes.mem.write {

        bset &RAM $calc($1 + 1) $2

        ;hadd nes.mem $1 $2
}

alias nes.mem.read {

        return $bvar(&RAM, $calc($1 + 1))

        ;return $hget(nes.mem, $1)
}

alias nes.mem.init {


        ;; set up RAM. just fill it with zeroes first.
        echo @nes.debug setting up RAM

        if ($hget(nes.mem) != $null) {

                hfree nes.mem
        }

        ;; 64k RAM space, plus a lil extra for other stuff.
        hmake nes.mem $calc(64 * 128)

        bset &RAM $calc(64 * 1024) 0

        ;; stack is 256 bytes from $0100 - $01FF.
        ;; it starts at $01FF and is filled from there, backwards.
        hadd nes.mem stackPointer 0
}

alias nes.mem.loadRom {

        echo -a loading ROM... (this may take a while)

        var %startAddress $1
        var %size $hget(nes.data, ROM.PRGsize)
        ;; for now assume &ROM already exists

        var %i 0

        while (%i < %size) {

                var %byte $bvar(&ROM, $calc(%i + 1))
                var %address $calc(%startAddress + %i)

                hadd nes.mem %address %byte

                ;echo -a . %address <- %byte

                inc %i
        }
}