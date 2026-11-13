"""Measure BF16 approximation error against host binary64 references."""

import ctypes
import math
from pathlib import Path
import subprocess
import tempfile


def value(bits):
    """Decode a positive normal BF16 pattern as binary64."""
    return math.ldexp(128 + (bits & 127), ((bits >> 7) & 255) - 134)


def main():
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="bf16-errors-") as directory:
        library = Path(directory) / "bf16.so"
        subprocess.run(
            ["cc", "-shared", "-fPIC", "-O2",
             str(root / "src/bf16/bf16.c"), "-o", str(library)],
            check=True,
        )
        lib = ctypes.CDLL(str(library))
        lib.bf16_sqrt.argtypes = [ctypes.c_uint16]
        lib.bf16_sqrt.restype = ctypes.c_uint16
        lib.bf16_mul.argtypes = [ctypes.c_uint16, ctypes.c_uint16]
        lib.bf16_mul.restype = ctypes.c_uint16
        worst_sqrt = (0.0, 0)
        for bits in range(0x0080, 0x7F80):
            error = abs(value(lib.bf16_sqrt(bits)) / math.sqrt(value(bits)) - 1)
            if error > worst_sqrt[0]:
                worst_sqrt = (error, bits)
        worst_mul = (0.0, 0, 0)
        for a in range(0x3F80, 0x4000):
            for b in range(0x3F80, 0x4000):
                error = abs(value(lib.bf16_mul(a, b)) / (value(a) * value(b)) - 1)
                if error > worst_mul[0]:
                    worst_mul = (error, a, b)
        print("sqrt maximum relative error:", worst_sqrt)
        print("normal mantissa product maximum relative error:", worst_mul)


if __name__ == "__main__":
    main()
