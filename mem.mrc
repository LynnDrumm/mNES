;; okay, let's write a stack handler now!! :3

;; add something to the stack
alias nes.mem.stack {

        ;; stack is 256 bytes from $0100 - $01FF.
        ;; it starts at $01FF and is filled from there, backwards.

        ;; address is start of stack minus offset (pointer).
        ;; this is always where we start any stack operations,
        ;; as it's organised first in, last out.
        ;; you wouldn't remove a block from the middle of a block tower,
        ;; ...would you?
        var %address $calc($base(01FF, 16, 10) - $hget(nes.mem, stackPointer))

        ;; put something on the stack
        if ($1 == push) {

                ;; check if we haven't reached stack overflow yet.
                ;; ...the programming concept, not the website,
                ;; i'm afraid to go there.
                if ($hget(nes.mem, stackPointer) > 0) {

                        var %value $2

                        ;; check if we're dealing with a 16-bit value
                        ;; typically an address. well, always, really
                        ;; unless there's some mystery 16-bit support
                        ;; on the 6502 aside from the address bus that
                        ;; i'm not aware of.
                        if (%value > 255) {

                                ;; we'll split this up into two bytes,
                                ;; in real proper cursed mIRC style, of course.
                                ;; isn't it fantastic that there's only 1 variable
                                ;; type, and everything can be manipulated as strings? :3

                                ;; make sure %value is hex and padded to 4 digits
                                var %value $base(%value, 10, 16, 4)

                                ;; split it up!
                                var %upper $left(%value, 2)
                                var %lower $right(%value, 2)

                                nes.mem.write       %address      %upper
                                nes.mem.write $calc(%address - 1) %lower

                                ;; decrease the stack pointer by 2,
                                ;; since we wrote 2 bytes. obvious!
                                hdec nes.mem stackPointer 2
                        }

                        else {

                                ;; write the value to the stack
                                nes.mem.write %address %value

                                ;; decrease the stack pointer
                                hdec nes.mem stackPointer
                        }
                }

                else {

                        echo @nes.debug /!\ 66,28 $+ $+($chr(160),stack overflow,$chr(160))
                        nes.cpu.stop
                }
        }

        ;; retrieve something from the stack
        elseif ($1 == pop) {

                ;; read the topmost stack value
                var %value $nes.mem.read(%addresses)

                ;; increase the stack pointer, we have extra space now!
                hinc nes.mem stackPointer

                return %value
        }
}

;; since stupid. fuckin. starting at 1.
;; yeah. so. here's an alternative that does the extra
;; math for us.
;; assumes decimal input
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
        hadd nes.mem stackPointer 256
}