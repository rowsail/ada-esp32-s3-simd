# ESP32-S3 SIMD Ada API

> **Status: experimental.** This library is not fully tested and should be treated
> as beta-quality code. Correctness has been validated for a subset of operations
> through the benchmark harness in `source/main.adb`, but edge cases, less common
> operation families, and interactions between operations have not been
> systematically exercised. Do not rely on this code in safety-critical or
> production contexts without independent verification.

This document describes the public SIMD API exposed by `ESP32.S3.SIMD` in this repository.

**Before you start:** if you are new to running Ada on the ESP32-S3, see the
[esp32s3_template](https://github.com/godunko/esp32s3_template) project first.
It provides a ready-to-use project skeleton, the correct Alire and ESP-IDF
configuration, and step-by-step instructions for building and flashing firmware.

## Overview

`ESP32.S3.SIMD` is the public Ada facade for SIMD-accelerated vector operations on the ESP32-S3.

- Target: ESP32-S3 (Xtensa LX7 with ESP32-S3 PIE SIMD instructions)
- Public package: `ESP32.S3.SIMD`
- Element families: `Integer_8`, `Integer_16`, `Integer_32`, `IEEE_Float_32`
- API style: overloaded Ada subprograms with `Pre` aspects for shape safety
- Implementation style: typed child packages under `ESP32.S3.SIMD` plus a convenience facade

The facade is what application code should `with`. The typed child packages such as
`ESP32.S3.SIMD.I8`, `ESP32.S3.SIMD.I16`, `ESP32.S3.SIMD.I32`, and `ESP32.S3.SIMD.F32`
hold the per-type implementations.

### SIMD terminology

**SIMD** stands for *Single Instruction, Multiple Data*. Instead of operating on one
value at a time, a single SIMD instruction performs the same operation simultaneously
across a set of values packed together in a wide register.

**Vector register** — a hardware register wide enough to hold several elements at once.
On the ESP32-S3, each SIMD vector register (`q0`–`q7`) is 128 bits wide. Depending on
the element type, a single register holds:

- 16 × `Integer_8` values
- 8 × `Integer_16` values
- 4 × `Integer_32` or `IEEE_Float_32` values

**Lane** — one element slot within a vector register. A 4-element vector has lanes 0
through 3. Element-wise operations work lane by lane: lane 0 of the result comes from
lane 0 of each input, lane 1 from lane 1, and so on.

**Element-wise operation** — an operation that is applied independently to each lane.
`Add(A, B, Result)` adds lane 0 of A to lane 0 of B, lane 1 to lane 1, etc.

**Reduction** — an operation that collapses the entire vector down to a single scalar
result. `Sum(A)` adds all lanes together; `Dot_Product(A, B)` multiplies matching
lanes and then sums those products.

**Saturation** — instead of wrapping around on overflow (which would silently corrupt
results), saturating arithmetic clamps the result to the nearest representable value.
For example, adding 100 to `Integer_8'Last` (127) with saturation gives 127, not -29.
All integer arithmetic in this library uses saturating semantics.

**Fixed-point** — a way to represent fractional values using plain integers by
reserving a fixed number of bits for the fractional part. `Mul_Shift` supports this
style: multiply two integers, then right-shift the product by `Shift` bits, effectively
dividing by 2^Shift. For example, multiplying two Q7 fixed-point numbers and shifting
right by 7 keeps the result in the same Q7 range.

**Mask vector** — the result of a comparison operation. Each lane is all-bits-set
(`-1` for signed integer types) where the condition was true, and zero where it was
false. Masks can be combined with `Bitwise_And` to select values conditionally.

**Scalar tail** — when a vector length is not a multiple of the SIMD width (e.g., 17
elements for a 4-lane `Integer_32` operation), the SIMD loop handles complete groups
and a small scalar loop cleans up the leftover elements. This library handles tails
transparently; the caller does not need to pad arrays.

**PIE SIMD** — the name Espressif gives to the SIMD extension built into the ESP32-S3's
Xtensa LX7 core. PIE stands for *Processor Instruction Extensions*. The `q`-register
load, store, and arithmetic instructions are part of this extension and are not
available on older ESP32 variants.

### Minimal Example

```ada
with ESP32.S3.SIMD;

procedure Example is
   use ESP32.S3.SIMD;

   A : SIMD_I16_Vector (0 .. 31) := (others => 100);
   B : SIMD_I16_Vector (0 .. 31) := (others => 25);
   R : SIMD_I16_Vector (0 .. 31) := (others => 0);

   Acc : Integer_32 := 0;
begin
   Add (A, B, R);
   MAC (A, Acc, Integer_16 (2));
end Example;
```

Example using the overloaded operators:

```ada
with ESP32.S3.SIMD;

procedure Example_Operators is
   use ESP32.S3.SIMD;

   A : SIMD_I32_Vector (0 .. 15) := (others => 10);
   B : SIMD_I32_Vector (0 .. 15) := (others => 3);
   C : SIMD_I32_Vector (0 .. 15);
begin
   C := (A + B) - Integer_32 (1);
end Example_Operators;
```

## Package Layout

Main public and implementation files:

- `source/esp32.ads`
- `source/esp32-s3.ads`
- `source/esp32-s3-simd.ads`
- `source/esp32-s3-simd.adb`
- `source/esp32-s3-simd-i8.ads`
- `source/esp32-s3-simd-i8.adb`
- `source/esp32-s3-simd-i16.ads`
- `source/esp32-s3-simd-i16.adb`
- `source/esp32-s3-simd-i32.ads`
- `source/esp32-s3-simd-i32.adb`
- `source/esp32-s3-simd-f32.ads`
- `source/esp32-s3-simd-f32.adb`

In normal use, application code only needs the facade:

```ada
with ESP32.S3.SIMD;
```

## Core Types

Scalar element types used by the API:

- `Integer_8`
- `Integer_16`
- `Integer_32`
- `IEEE_Float_32`

Aligned vector types:

- `SIMD_I8_Vector`
- `SIMD_I16_Vector`
- `SIMD_I32_Vector`
- `SIMD_F32_Vector`

Each vector type has `Alignment => 16`, so objects declared with these types are suitable for the ESP32-S3 128-bit SIMD instructions.

## Alignment and Length Rules

1. Use the provided SIMD vector types directly whenever possible.
2. Those types guarantee 16-byte alignment for declared objects.
3. Do not assume slices, overlays, or foreign buffers are safe unless you also guarantee 16-byte alignment.
4. Any vector length is allowed.
5. Best throughput usually comes from lengths that are friendly to the SIMD loop structure.
6. Non-multiple tails are handled by scalar cleanup code after the vectorized path.

## Public Operation Families

The facade exposes overloads across the supported element families.

Arithmetic:

- `Add`
- `Add_Scalar`
- `Sub`
- `Mul_Shift`
- `Mul_Scalar`
- `Mul_Widen`

Unary math:

- `Neg`
- `Abs_Val`

Reductions:

- `Sum`
- `Dot_Product`
- `MAC`

Clamp and activation:

- `Relu` for `Integer_8` and `Integer_16`
- `Ceil`
- `Floor`

Selection and comparison:

- `Max`
- `Min`
- `Compare_GT`
- `Compare_LT`
- `Compare_EQ`

Bitwise integer operations:

- `Bitwise_And`
- `Bitwise_Or`
- `Bitwise_Xor`
- `Bitwise_Not`

Bulk operations:

- `Zeros`
- `Ones`
- `Fill`
- `Copy`

Conversions:

- `Convert` from `Integer_8` to `Integer_16`
- `Convert` from `Integer_8` to `Integer_32`
- `Convert` from `Integer_16` to `Integer_32`

Operator overloads are also provided for the common arithmetic cases, including vector-vector, vector-scalar, unary minus, and multiplication forms where they make sense.

## Function Reference

This section explains what each public operation means in plain language.

Element-wise arithmetic:

- `Add(A, B, Result)`: adds matching lanes from `A` and `B` and writes the result to `Result`.
- `Add_Scalar(A, Scalar, Result)`: adds the same scalar value to every lane of `A`.
- `Sub(A, B, Result)`: subtracts each lane of `B` from the matching lane of `A`.
- `Mul_Shift(A, B, Result, Shift)`: multiplies matching lanes, then right-shifts the product for fixed-point style scaling in the integer variants.
- `Mul_Scalar(A, Scalar, Result, Shift)`: multiplies every lane by one scalar, then right-shifts for the integer fixed-point variants.
- `Mul_Widen(A, B, Result)`: multiplies integer lanes and stores the products in a wider destination type so the result has more headroom.

Operator forms:

- `"+"`, `"-"`, and `"*"`: expression-friendly forms of the matching arithmetic operations.
- unary `"-"(A)`: negates every lane in `A`.
- vector-scalar and scalar-vector operator overloads: shorthand for adding, subtracting, or multiplying a whole vector by one scalar value.

Unary math:

- `Neg(A, Result)`: negates each lane.
- `Abs_Val(A, Result)`: replaces each lane with its absolute value.

Reductions:

- `Sum(A)`: adds all lanes together and returns one scalar result.
- `Dot_Product(A, B)`: multiplies matching lanes and returns the sum of all those products.
- `MAC(A, Accumulator, Multiplier)`: multiply-accumulate. It updates the scalar accumulator with the sum of `A(i) * Multiplier` across the vector.

Clamp and activation:

- `Relu(A, Multiplier, Shift, Result)`: applies the package's parameterized ReLU-style transform to the negative lanes of `A` and leaves non-negative lanes unchanged.
- `Ceil(A, Result, Max_Val)`: clamps each lane from above so no result is greater than `Max_Val`.
- `Floor(A, Result, Min_Val)`: clamps each lane from below so no result is less than `Min_Val`.

Selection and comparison:

- `Max(A, B, Result)`: writes the larger value from each pair of lanes.
- `Min(A, B, Result)`: writes the smaller value from each pair of lanes.
- `Compare_GT(A, B, Result)`: writes a true-mask where `A(i) > B(i)`, otherwise zero.
- `Compare_LT(A, B, Result)`: writes a true-mask where `A(i) < B(i)`, otherwise zero.
- `Compare_EQ(A, B, Result)`: writes a true-mask where `A(i) = B(i)`, otherwise zero.

Bitwise integer operations:

- `Bitwise_And(A, B, Result)`: bitwise AND on matching integer lanes.
- `Bitwise_Or(A, B, Result)`: bitwise OR on matching integer lanes.
- `Bitwise_Xor(A, B, Result)`: bitwise XOR on matching integer lanes.
- `Bitwise_Not(A, Result)`: bitwise inversion of each integer lane.

Bulk operations:

- `Zeros(A)`: fills the whole vector with zero.
- `Ones(A)`: fills the whole vector with one.
- `Fill(A, Value)`: fills the whole vector with the same value.
- `Copy(A, Result)`: copies all lanes from `A` into `Result`.

Conversions:

- `Convert(A, Result)`: converts every integer lane to a wider integer type while keeping the same element count.

## Shape Safety

Most procedures and functions in `ESP32.S3.SIMD` use `Pre` aspects to reject invalid shapes.

Typical rules are:

- Binary element-wise operations require matching input lengths and a matching result length.
- Unary transforms require `A'Length = Result'Length`.
- Binary reductions such as `Dot_Product` require matching input lengths.
- Conversions require the same number of elements on input and output.

If contract checks are enabled, violating these preconditions raises `Assertion_Error`.

## Numeric Semantics

Some semantics are type-specific and worth calling out explicitly.

- Integer `Add`, `Sub`, `Neg`, and `Abs_Val` use saturating behavior.
- Integer `Mul_Shift` and `Mul_Scalar` are fixed-point style operations with a right shift after multiplication.
- Floating-point variants use normal IEEE floating arithmetic rather than fixed-point shifting.
- Integer reductions return `Integer_32`.
- Floating reductions return `IEEE_Float_32`.
- Comparison results use all bits set for true and zero for false in the integer result vectors.
- `Relu` is currently available for `Integer_8` and `Integer_16`, not for `Integer_32` or `IEEE_Float_32`.

## Worked Examples

The examples below use 4-element vectors to keep the before/after values easy to read.

### `Mul_Shift`

`Mul_Shift` multiplies matching lanes and then right-shifts the product by the given amount. It is used for fixed-point scaling where dividing by a power of two is expressed as a shift.

```ada
A     : SIMD_I32_Vector (0 .. 3) := (100, 200, -50, -300);
B     : SIMD_I32_Vector (0 .. 3) := (  3,   4,   5,    6);
R     : SIMD_I32_Vector (0 .. 3);
Shift : constant Natural := 2;  -- divide product by 4

Mul_Shift (A, B, R, Shift);

--  Lane 0:  100 *   3 =   300, >> 2 =  75
--  Lane 1:  200 *   4 =   800, >> 2 = 200
--  Lane 2:  -50 *   5 =  -250, >> 2 = -63   (arithmetic shift rounds toward -inf)
--  Lane 3: -300 *   6 = -1800, >> 2 = -450
--
--  R is now (75, 200, -63, -450)
```

The right shift is arithmetic: negative products round toward negative infinity, not toward zero.

### `Compare_GT`, `Compare_LT`, `Compare_EQ`

Comparison operations produce a mask vector. Each output lane is all bits set (`-1` for signed integer types) where the condition is true, and zero where it is false. The mask can be used directly with bitwise operations to select values.

```ada
A : SIMD_I32_Vector (0 .. 3) := ( 10, -5,  0, 20);
B : SIMD_I32_Vector (0 .. 3) := (  5,  0,  0, 30);
M : SIMD_I32_Vector (0 .. 3);

Compare_GT (A, B, M);   --  where is A(i) > B(i)?
--  Lane 0:  10 >  5  => true  => -1 (all bits set)
--  Lane 1:  -5 >  0  => false =>  0
--  Lane 2:   0 >  0  => false =>  0
--  Lane 3:  20 > 30  => false =>  0
--
--  M is now (-1, 0, 0, 0)

Compare_EQ (A, B, M);   --  where is A(i) = B(i)?
--  Lane 0:  10 =  5  => false =>  0
--  Lane 1:  -5 =  0  => false =>  0
--  Lane 2:   0 =  0  => true  => -1
--  Lane 3:  20 = 30  => false =>  0
--
--  M is now (0, 0, -1, 0)
```

### `Relu`

`Relu` is a parameterized activation function. For each lane, if the value is negative it is multiplied by `Multiplier` and then right-shifted by `Shift`; if it is zero or positive it is left unchanged.

Setting `Multiplier => 0` gives classic ReLU (clamp negatives to zero). Setting `Multiplier => 1` and `Shift => 1` gives a leaky half-step, and so on.

```ada
A   : SIMD_I16_Vector (0 .. 3) := (-40, -10, 0, 30);
R   : SIMD_I16_Vector (0 .. 3);

--  Classic ReLU: suppress negatives entirely
Relu (A, Multiplier => 0, Shift => 0, Result => R);
--  Lane 0:  -40 < 0  => (-40 * 0) >> 0 =    0
--  Lane 1:  -10 < 0  => (-10 * 0) >> 0 =    0
--  Lane 2:    0 >= 0 =>  unchanged      =    0
--  Lane 3:   30 >= 0 =>  unchanged      =   30
--
--  R is now (0, 0, 0, 30)

--  Leaky variant: negative lanes kept but halved
Relu (A, Multiplier => 1, Shift => 1, Result => R);
--  Lane 0:  -40 < 0  => (-40 * 1) >> 1 =  -20
--  Lane 1:  -10 < 0  => (-10 * 1) >> 1 =   -5
--  Lane 2:    0 >= 0 =>  unchanged      =    0
--  Lane 3:   30 >= 0 =>  unchanged      =   30
--
--  R is now (-20, -5, 0, 30)
```

## Benchmark Harness

This project includes correctness checks and per-operation benchmarks in:

- `source/main.adb`

The benchmark harness compares the SIMD implementation against scalar Ada reference code using the same input data and reports elapsed time and speedup.

Typical output includes:

- a correctness phase for selected operations
- per-operation SIMD and scalar timings
- a computed speedup column
- an overall summary line

To run the application with ESP-IDF:

```bash
idf.py build flash monitor
```

If you only want to rebuild the firmware:

```bash
idf.py build
```

### Captured Results (ESP32-S3, May 2026)

The following results were captured from a real board run of the benchmark
harness in `source/main.adb`.

The firmware image used for these measurements was built with `-O3`, and the
benchmark code disables runtime checks in the timing sections to keep the
measurements representative of the optimized hot path.

- Benchmark shape: 1024 elements, 64 iterations per operation
- Timing source: `esp_timer_get_time()`

```text
=== Per-Function Benchmark (1024 elements, 64 iterations) ===
Operation            SIMD_us  Scalar_us  Speedup
─────────────────────────────────────────────────
Add i8                  171   6987  40.9x
Add i16                 278   6578  23.7x
Add i32                 476   2877  6.0x
Add f32                 1096   3704  3.4x
Add_Scalar i8           105   6160  58.7x
Add_Scalar i16          156   6969  44.7x
Add_Scalar i32          258   2054  7.10x
Add_Scalar f32          982   4113  4.2x
Sub i8                  167   6571  39.3x
Sub i16                 276   6569  23.8x
Sub i32                 474   2886  6.1x
Sub f32                 1093   3696  3.4x
Mul_Shift i8            203   9071  44.7x
Mul_Shift i16           323   10431  32.3x
Mul_Shift i32           3270   4114  1.3x
Mul_Shift f32           1099   3696  3.4x
Mul_Scalar i8           139   852  6.1x
Mul_Scalar i16          215   1658  7.7x
Mul_Scalar i32          2323   1646  0.7x
Mul_Scalar f32          982   3284  3.3x
Mul_Widen i8->i16       301   3706  12.3x
Mul_Widen i16->i32      531   2877  5.4x
Neg i8                  157   6568  41.8x
Neg i16                 265   6569  24.8x
Neg i32                 1495   2056  1.4x
Neg f32                 473   2057  4.3x
Abs_Val i8              186   3286  17.7x
Abs_Val i16             313   2876  9.2x
Abs_Val i32             1494   2055  1.4x
Abs_Val f32             461   2056  4.5x
Sum i8                  95   1648  17.3x
Sum i16                 150   1235  8.2x
Sum i32                 251   1236  4.9x
Sum f32                 568   3285  5.8x
Dot_Product i8          131   3297  25.2x
Dot_Product i16         210   2058  9.8x
Dot_Product i32         1894   2468  1.3x
Dot_Product f32         683   3695  5.4x
MAC i8                  103   1647  15.10x
MAC i16                 153   1237  8.1x
MAC i32                 1380   1246  0.9x
MAC f32                 571   3695  6.5x
Relu i8                 182   843  4.6x
Relu i16                318   1657  5.2x
Ceil i8                 105   2466  23.5x
Ceil i16                160   2065  12.9x
Ceil i32                261   2055  7.9x
Ceil f32                1089   3702  3.4x
Floor i8                106   2465  23.3x
Floor i16               162   2055  12.7x
Floor i32               260   2055  7.9x
Floor f32               1087   3704  3.4x
Max i8                  166   3698  22.3x
Max i16                 273   2885  10.6x
Max i32                 472   2877  6.1x
Max f32                 1198   3295  2.8x
Min i8                  166   3697  22.3x
Min i16                 270   2885  10.7x
Min i32                 474   2878  6.1x
Min f32                 1198   3287  2.7x
Compare_GT i8           189   4106  21.7x
Compare_GT i16          325   3287  10.1x
Compare_GT i32          576   3295  5.7x
Compare_LT i8           183   4107  22.4x
Compare_LT i16          326   3295  10.1x
Compare_LT i32          574   3287  5.7x
Compare_EQ i8           180   4935  27.4x
Compare_EQ i16          325   4114  12.7x
Compare_EQ i32          577   4106  7.1x
Bitwise_And i8          180   842  4.7x
Bitwise_And i16         317   1655  5.2x
Bitwise_And i32         574   1646  2.9x
Bitwise_Or i8           181   844  4.7x
Bitwise_Or i16          320   1657  5.2x
Bitwise_Or i32          575   1646  2.9x
Bitwise_Xor i8          182   852  4.7x
Bitwise_Xor i16         322   1657  5.1x
Bitwise_Xor i32         575   1646  2.9x
Bitwise_Not i8          144   851  5.9x
Bitwise_Not i16         255   1657  6.5x
Bitwise_Not i32         460   1646  3.6x
Fill/Zeros/Ones/Copy    417   1693  4.1x
Convert i8->i32         473   2061  4.4x
Convert i16->i32        474   1654  3.5x
─────────────────────────────────────────────────
OVERALL               42602   259877  6.1x
```

These numbers are workload-dependent and should be treated as a point-in-time
reference rather than a guaranteed performance target.


## Implementation Notes

The public facade is intentionally higher-level than the per-type implementation packages.

- The facade groups all overloads under one package name.
- Many simple pass-through wrappers in the facade are expressed as renames.
- Some operations remain explicit wrappers because they adapt names or result types between the facade and child packages.
- The integer implementations use Ada plus GNAT inline assembly where it is useful to reach ESP32-S3 SIMD instructions directly.
- Scalar tail paths are kept alongside SIMD paths so non-vector-multiple lengths still work correctly.

## Maintenance Notes

When extending this API:

1. Update the public declarations in `source/esp32-s3-simd.ads`.
2. Keep the facade in `source/esp32-s3-simd.adb` aligned with the child-package API.
3. Add or update the matching typed child package implementation.
4. Preserve the documented shape and alignment requirements.
5. Update `source/main.adb` if the benchmark harness should exercise the new operation.

## Upstream Reference

This work is based on the ESP32-S3 SIMD instruction set and related low-level implementation ideas from the upstream `esp_simd` project:

- https://github.com/zliu43/esp_simd
