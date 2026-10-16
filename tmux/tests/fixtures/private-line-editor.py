import os
import sys
import termios
import tty

path = sys.argv[1]
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
before = termios.tcgetattr(0)
draft = bytearray()
inputs = 0
submits = 0
last = b""

def record():
    row = f"{inputs}\t{submits}\t{draft.hex()}\t{last.hex()}\n".encode()
    os.write(fd, row)

def render():
    os.write(1, b"\r\x1b[2Kfixture> " + draft)

try:
    tty.setraw(0)
    render()
    record()
    while True:
        value = os.read(0, 1)
        if not value:
            break
        inputs += 1
        if value in (b"\r", b"\n"):
            last = bytes(draft)
            submits += 1
            draft.clear()
            os.write(1, b"\r\nsubmitted> " + last + b"\r\n")
        elif 32 <= value[0] <= 126:
            draft.extend(value)
        else:
            raise RuntimeError("unsupported fixture input byte")
        render()
        record()
finally:
    termios.tcsetattr(0, termios.TCSANOW, before)
    os.close(fd)
