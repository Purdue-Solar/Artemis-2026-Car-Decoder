import math
import os
import random
from datetime import datetime, timedelta, timezone
import struct

root = "/Users/nansonchen/GitHub/Artemis-2026-Car-Decoder"
out_path = os.path.join(root, "Test", "synthetic_12h_500.hex")
expected_path = os.path.join(root, "Test_Expected", "synthetic_12h_500.expected.csv")

random.seed(2026)

message_count = 500
start = datetime(2026, 2, 21, 8, 0, 0, tzinfo=timezone.utc)
end = datetime(2026, 2, 21, 20, 0, 0, tzinfo=timezone.utc)
span = (end - start).total_seconds()


def float_to_bfloat16(value: float) -> int:
    bits = struct.unpack(">I", struct.pack(">f", float(value)))[0]
    return (bits >> 16) & 0xFFFF


def bfloat16_to_float(value: int) -> float:
    bits = (value & 0xFFFF) << 16
    return struct.unpack(">f", struct.pack(">I", bits))[0]


lines = []
expected_lines = []
for i in range(message_count):
    t = start + timedelta(seconds=span * i / (message_count - 1))
    unix_ts = int(t.timestamp())

    progress = i / (message_count - 1)
    battery_temp = 22 + 14 * math.sin(progress * math.pi) + random.uniform(-1.5, 1.5)
    battery_temp = max(15, min(55, battery_temp))

    soc = 100 - int(60 * progress + random.uniform(-1, 1))
    soc = max(20, min(100, soc))

    limit = int(5 + 40 * math.sin(progress * math.pi) + random.uniform(-3, 3))
    limit = max(0, min(100, limit))

    diag_one = 0
    diag_two = 0
    if random.random() < 0.02:
        diag_one = random.randint(1, 3)
    if random.random() < 0.01:
        diag_two = random.randint(1, 2)

    motor_curr = 20 + 180 * math.sin(progress * math.pi) + random.uniform(-15, 15)
    motor_curr = max(-20, min(250, motor_curr))

    motor_vel = 500 + 5500 * math.sin(progress * math.pi) + random.uniform(-200, 200)
    motor_vel = max(0, min(7000, motor_vel))

    sink = 25 + 20 * math.sin(progress * math.pi) + random.uniform(-2, 2)
    sink = max(20, min(70, sink))

    temp = 30 + 30 * math.sin(progress * math.pi) + random.uniform(-3, 3)
    temp = max(20, min(80, temp))

    regen = 1 if motor_curr < 10 and motor_vel > 500 else 0
    cruise_down = 1 if random.random() < 0.03 else 0
    cruise_up = 1 if random.random() < 0.03 else 0
    cruise = 1 if 0.1 < progress < 0.9 else 0
    aux_over_voltage = 1 if random.random() < 0.005 else 0
    aux_under_voltage = 1 if random.random() < 0.01 else 0
    aux_over_current = 1 if random.random() < 0.005 else 0
    aux_current_warning = 1 if random.random() < 0.02 else 0
    main_over_voltage = 1 if random.random() < 0.002 else 0
    main_under_voltage = 1 if soc < 35 and random.random() < 0.05 else 0
    main_over_current_error = 1 if motor_curr > 230 and random.random() < 0.05 else 0
    main_current_warning = 1 if motor_curr > 200 else 0
    aux_condition = random.randint(0, 15)

    flags = (
        (regen << 0)
        | (cruise_down << 1)
        | (cruise_up << 2)
        | (cruise << 3)
        | (aux_over_voltage << 4)
        | (aux_under_voltage << 5)
        | (aux_over_current << 6)
        | (aux_current_warning << 7)
        | (main_over_voltage << 8)
        | (main_under_voltage << 9)
        | (main_over_current_error << 10)
        | (main_current_warning << 11)
        | ((aux_condition & 0x0F) << 12)
    )

    parts = []
    parts.extend(unix_ts.to_bytes(4, byteorder="little", signed=False))
    parts.append(int(round(battery_temp)) & 0xFF)
    parts.append(soc & 0xFF)
    parts.append(limit & 0xFF)
    parts.append(diag_one & 0xFF)
    parts.append(diag_two & 0xFF)

    for value in (motor_curr, motor_vel, sink, temp):
        bf16 = float_to_bfloat16(value)
        parts.extend(bf16.to_bytes(2, byteorder="little", signed=False))

    parts.extend(flags.to_bytes(2, byteorder="little", signed=False))

    if len(parts) != 19:
        raise RuntimeError(f"Message length {len(parts)}")

    line = " ".join(f"{b:02X}" for b in parts)
    lines.append(line)

    # Build expected CSV line (same format as test harness)
    motor_curr_bf = bfloat16_to_float(float_to_bfloat16(motor_curr))
    motor_vel_bf = bfloat16_to_float(float_to_bfloat16(motor_vel))
    sink_bf = bfloat16_to_float(float_to_bfloat16(sink))
    temp_bf = bfloat16_to_float(float_to_bfloat16(temp))

    bools = [
        regen,
        cruise_down,
        cruise_up,
        cruise,
        aux_over_voltage,
        aux_under_voltage,
        aux_over_current,
        aux_current_warning,
        main_over_voltage,
        main_under_voltage,
        main_over_current_error,
        main_current_warning,
    ]

    bool_text = ",".join("True" if b else "False" for b in bools)
    expected_lines.append(
        f"{unix_ts},{int(round(battery_temp))},{soc},{limit},{diag_one},{diag_two},"
        f"{motor_curr_bf:.6f},{motor_vel_bf:.6f},{sink_bf:.6f},{temp_bf:.6f},"
        f"{bool_text},{aux_condition}"
    )

with open(out_path, "w", encoding="ascii") as f:
    for line in lines:
        f.write(line + "\n")

with open(expected_path, "w", encoding="ascii") as f:
    for line in expected_lines:
        f.write(line + "\n")

print(f"Wrote {len(lines)} messages to {out_path}")
print(f"Wrote {len(expected_lines)} expected rows to {expected_path}")
