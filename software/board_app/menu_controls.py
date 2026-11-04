"""Explicit title-menu adapter; ordinary gameplay always keeps native directions."""
class MenuControls:
    def __init__(self):
        self.enabled = False
        self.previous = 0
        self.pulse_until = 0.0
        self.rearm_at = 0.0

    def toggle(self):
        self.enabled = not self.enabled
        self.pulse_until = self.rearm_at = 0.0

    def apply(self, state, now):
        rising = (state & ~self.previous) & 0xf0
        self.previous = state
        if state & 0x08:  # Start confirms and restores movement immediately.
            self.enabled = False
            self.pulse_until = self.rearm_at = 0.0
        if not self.enabled:
            return state
        # A direction tap produces one 100 ms Select pulse. Suppress the
        # direction in this mode so ROMs supporting both do not step twice.
        if rising and now >= self.rearm_at:
            self.pulse_until = now + 0.10
            self.rearm_at = now + 0.20
        return (state & 0x0f) | (0x04 if now < self.pulse_until else 0)

    def release(self):
        self.previous = 0
        self.pulse_until = self.rearm_at = 0.0
