alias nes.ppu.init {

        ;; there are some initial register values the PPU
        ;; has on reset. of course, in the real world,
        ;; any "random" values are influenced by things like
        ;; heat, electro-magnetism, and other things we're not
        ;; going to bother emulating.

        ;; there is a fantastic document at
        ;; https://www.nesdev.org/wiki/PPU_power_up_state
        ;; that we'll go by, mainly just setting bits that
        ;; are "often set", and ignoring most of the rest.

        ;; PPU CTRL
        nes.mem.write $dec(2000) $dec(00000000).bin

        ;; PPU MASK
        nes.mem.write $dec(2001) $dec(00000000).bin

        ;; PPU STATUS
        ;; bits 5 and 7 are "often set", 6 is always 0,
        ;; the others are irrelevant. hardcoded for now.
        nes.mem.write $dec(2002) $dec(10100000).bin

        ;; everything else should just be 0, which
        ;; we already do, but we can specifically force
        ;; them here in the future if needed.
}



;; explicit hex -> decimal conversion
;; .bin for conversaion from binary
alias -l dec {

        return $base($1, $iif($prop == bin, 2, 16), 10)
}