;; okay, let's write a stack handler now!! :3

;; add something to the stack

;; i got SO many things backwards here in several different ways at the same time
alias nes.mem.stack {

        ;; stack is 256 bytes from $0100 - $01FF.
        ;; it starts at $01FF and is filled from there, backwards.

        ;; address is start of stack minus offset (pointer).
        ;; this is always where we start any stack operations,
        ;; as it's organised first in, last out.
        ;; you wouldn't remove a block from the middle of a block tower,
        ;; ...would you?

        ;; ok, for some reason every time we pop, we're off by 1.
        ;; i've been staring at this for over an hour now and i can't make
        ;; any sense of it. so, we're just going to do this the stupid way,
        ;; tell me if you figure it out because i think i'm losing it

        var %baseAddress $base(01FF, 16, 10)
        var %address $calc(%baseAddress - $hget(nes.mem, stackPointer))

        ;; put something on the stack
        if ($1 == push) {

                ;; check if we haven't reached stack overflow yet.
                ;; ...the programming concept, not the website,
                ;; i'm afraid to go there.
                if ($hget(nes.mem, stackPointer) < 255) {

                        var %value $2

                        ;; write the value to the stack
                        nes.mem.write %address %value

                        ;; increase the stack pointer
                        hinc nes.mem stackPointer
                }

                else {

                        echo @nes.debug /!\ 66,28 $+ $+($chr(160),stack overflow,$chr(160))
                        nes.cpu.stop
                }
        }

        ;; retrieve something from the stack
        elseif ($1 == pop) {

                ;; read the topmost stack value
                var %value $calc($nes.mem.read(%address) + 1)

                ;; decrease stack pointer
                hdec nes.mem stackPointer
        }

        echo -s . stack ptr: $hget(nes.mem, stackPointer) $1 $base(%address, 10, 16, 4) -> $base(%value, 10, 16, 2)

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