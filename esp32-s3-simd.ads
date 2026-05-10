pragma Ada_2022;

--  Ada bindings for the esp_simd library SIMD operations on the ESP32-S3.
--
--  The ESP32-S3 Xtensa LX7 core includes custom PIE (Processor Instruction
--  Extension) SIMD instructions operating on 128-bit vector registers.  This
--  package directly imports the hand-written assembly kernels from the
--  esp_simd component, providing a safe, type-checked Ada interface.
--
--  ALIGNMENT REQUIREMENT: All array arguments must be 16-byte (128-bit)
--  aligned.  Declaring objects of the array types defined here guarantees
--  this alignment automatically.  Passing slices or overlays of other
--  storage that is not 16-byte aligned will cause a hardware exception.
--
--  SIZE REQUIREMENT: Best SIMD throughput is achieved when the array length
--  is a multiple of 16 elements.  Non-multiple-of-16 tails are handled
--  by a scalar fallback inside the assembly, so any length is valid.

with Interfaces;
use Interfaces;

package ESP32.S3.SIMD is

   --  -----------------------------------------------------------------------
   --  Element scalar subtypes -- these correspond to the C types used by the
   --  underlying assembly kernels.
   --  -----------------------------------------------------------------------


   --  -----------------------------------------------------------------------
   --  16-byte aligned array types.  Objects declared with these types are
   --  automatically 16-byte aligned, satisfying the SIMD requirement.
   --  -----------------------------------------------------------------------

   type SIMD_I8_Vector    is array (Natural range <>) of Integer_8
      with Alignment => 16;
   type SIMD_I16_Vector   is array (Natural range <>) of Integer_16
      with Alignment => 16;
   type SIMD_I32_Vector   is array (Natural range <>) of Integer_32
      with Alignment => 16;
   type SIMD_F32_Vector is array (Natural range <>) of IEEE_Float_32
      with Alignment => 16;

   --  -----------------------------------------------------------------------
   --  Saturated element-wise addition
   --    Result(i) := clamp(A(i) + B(i))
   --  Integer variants saturate at the type boundary; float uses IEEE add.
   --  -----------------------------------------------------------------------

   procedure Add (A       : SIMD_I8_Vector;
                  B       : SIMD_I8_Vector;
                  Result  : in out SIMD_I8_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Add (A       : SIMD_I16_Vector;
                  B       : SIMD_I16_Vector;
                  Result  : in out SIMD_I16_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Add (A       : SIMD_I32_Vector;
                  B       : SIMD_I32_Vector;
                  Result  : in out SIMD_I32_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Add (A       : SIMD_F32_Vector;
                  B       : SIMD_F32_Vector;
                  Result  : in out SIMD_F32_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   --  -----------------------------------------------------------------------
   --  Add a scalar to every element
   --    Result(i) := clamp(A(i) + Scalar)
   --  -----------------------------------------------------------------------

   procedure Add_Scalar (A      : SIMD_I8_Vector;
                         Scalar : Integer_8;
                         Result : in out SIMD_I8_Vector)
      with Pre => A'Length = Result'Length;

   procedure Add_Scalar (A      : SIMD_I16_Vector;
                         Scalar : Integer_16;
                         Result : in out SIMD_I16_Vector)
      with Pre => A'Length = Result'Length;

   procedure Add_Scalar (A      : SIMD_I32_Vector;
                         Scalar : Integer_32;
                         Result : in out SIMD_I32_Vector)
      with Pre => A'Length = Result'Length;

   procedure Add_Scalar (A      : SIMD_F32_Vector;
                         Scalar : IEEE_Float_32;
                         Result : in out SIMD_F32_Vector)
      with Pre => A'Length = Result'Length;

   --  -----------------------------------------------------------------------
   --  Saturated element-wise subtraction
   --    Result(i) := clamp(A(i) - B(i))
   --  -----------------------------------------------------------------------

   procedure Sub (A       : SIMD_I8_Vector;
                  B       : SIMD_I8_Vector;
                  Result  : in out SIMD_I8_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Sub (A       : SIMD_I16_Vector;
                  B       : SIMD_I16_Vector;
                  Result  : in out SIMD_I16_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Sub (A       : SIMD_I32_Vector;
                  B       : SIMD_I32_Vector;
                  Result  : in out SIMD_I32_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Sub (A       : SIMD_F32_Vector;
                  B       : SIMD_F32_Vector;
                  Result  : in out SIMD_F32_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   --  -----------------------------------------------------------------------
   --  Operator overloads for vector expressions
   --    C := A + B
   --    C := A - B
   --    C := -A
   --  Semantics match Add/Sub/Neg procedures for each element type.
   --  -----------------------------------------------------------------------

   function "+" (A, B : SIMD_I8_Vector) return SIMD_I8_Vector
      with Pre => A'Length = B'Length;

   function "+" (A, B : SIMD_I16_Vector) return SIMD_I16_Vector
      with Pre => A'Length = B'Length;

   function "+" (A, B : SIMD_I32_Vector) return SIMD_I32_Vector
      with Pre => A'Length = B'Length;

   function "+" (A, B : SIMD_F32_Vector) return SIMD_F32_Vector
      with Pre => A'Length = B'Length;

   function "-" (A, B : SIMD_I8_Vector) return SIMD_I8_Vector
      with Pre => A'Length = B'Length;

   function "-" (A, B : SIMD_I16_Vector) return SIMD_I16_Vector
      with Pre => A'Length = B'Length;

   function "-" (A, B : SIMD_I32_Vector) return SIMD_I32_Vector
      with Pre => A'Length = B'Length;

   function "-" (A, B : SIMD_F32_Vector) return SIMD_F32_Vector
      with Pre => A'Length = B'Length;

   function "-" (A : SIMD_I8_Vector) return SIMD_I8_Vector;
   function "-" (A : SIMD_I16_Vector) return SIMD_I16_Vector;
   function "-" (A : SIMD_I32_Vector) return SIMD_I32_Vector;
   function "-" (A : SIMD_F32_Vector) return SIMD_F32_Vector;

   --  Scalar operators
   function "+" (A : SIMD_I8_Vector; Scalar : Integer_8) return SIMD_I8_Vector;
   function "+" (A : SIMD_I16_Vector; Scalar : Integer_16) return SIMD_I16_Vector;
   function "+" (A : SIMD_I32_Vector; Scalar : Integer_32) return SIMD_I32_Vector;
   function "+" (A : SIMD_F32_Vector; Scalar : IEEE_Float_32) return SIMD_F32_Vector;

   function "+" (Scalar : Integer_8; A : SIMD_I8_Vector) return SIMD_I8_Vector;
   function "+" (Scalar : Integer_16; A : SIMD_I16_Vector) return SIMD_I16_Vector;
   function "+" (Scalar : Integer_32; A : SIMD_I32_Vector) return SIMD_I32_Vector;
   function "+" (Scalar : IEEE_Float_32; A : SIMD_F32_Vector) return SIMD_F32_Vector;

   function "-" (A : SIMD_I8_Vector; Scalar : Integer_8) return SIMD_I8_Vector;
   function "-" (A : SIMD_I16_Vector; Scalar : Integer_16) return SIMD_I16_Vector;
   function "-" (A : SIMD_I32_Vector; Scalar : Integer_32) return SIMD_I32_Vector;
   function "-" (A : SIMD_F32_Vector; Scalar : IEEE_Float_32) return SIMD_F32_Vector;

   function "-" (Scalar : Integer_8; A : SIMD_I8_Vector) return SIMD_I8_Vector;
   function "-" (Scalar : Integer_16; A : SIMD_I16_Vector) return SIMD_I16_Vector;
   function "-" (Scalar : Integer_32; A : SIMD_I32_Vector) return SIMD_I32_Vector;
   function "-" (Scalar : IEEE_Float_32; A : SIMD_F32_Vector) return SIMD_F32_Vector;

   --  Multiplication operators
   --  Integer variants use shift=0 semantics of Mul_Shift / Mul_Scalar.
   function "*" (A, B : SIMD_I8_Vector) return SIMD_I8_Vector
      with Pre => A'Length = B'Length;
   function "*" (A, B : SIMD_I16_Vector) return SIMD_I16_Vector
      with Pre => A'Length = B'Length;
   function "*" (A, B : SIMD_I32_Vector) return SIMD_I32_Vector
      with Pre => A'Length = B'Length;
   function "*" (A, B : SIMD_F32_Vector) return SIMD_F32_Vector
      with Pre => A'Length = B'Length;

   function "*" (A : SIMD_I8_Vector; Scalar : Integer_8) return SIMD_I8_Vector;
   function "*" (A : SIMD_I16_Vector; Scalar : Integer_16) return SIMD_I16_Vector;
   function "*" (A : SIMD_I32_Vector; Scalar : Integer_32) return SIMD_I32_Vector;
   function "*" (A : SIMD_F32_Vector; Scalar : IEEE_Float_32) return SIMD_F32_Vector;

   function "*" (Scalar : Integer_8; A : SIMD_I8_Vector) return SIMD_I8_Vector;
   function "*" (Scalar : Integer_16; A : SIMD_I16_Vector) return SIMD_I16_Vector;
   function "*" (Scalar : Integer_32; A : SIMD_I32_Vector) return SIMD_I32_Vector;
   function "*" (Scalar : IEEE_Float_32; A : SIMD_F32_Vector) return SIMD_F32_Vector;

   --  -----------------------------------------------------------------------
   --  Element-wise multiply with logical right-shift (fixed-point scaling)
   --    Result(i) := (A(i) * B(i)) >> Shift
   --  For IEEE_Float_32 the Shift argument is ignored and the result is A(i)*B(i).
   --  -----------------------------------------------------------------------

   procedure Mul_Shift (A      : SIMD_I8_Vector;
                        B      : SIMD_I8_Vector;
                        Result : in out SIMD_I8_Vector;
                        Shift  : Natural)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Mul_Shift (A      : SIMD_I16_Vector;
                        B      : SIMD_I16_Vector;
                        Result : in out SIMD_I16_Vector;
                        Shift  : Natural)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Mul_Shift (A      : SIMD_I32_Vector;
                        B      : SIMD_I32_Vector;
                        Result : in out SIMD_I32_Vector;
                        Shift  : Natural)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Mul_Shift (A      : SIMD_F32_Vector;
                        B      : SIMD_F32_Vector;
                        Result : in out SIMD_F32_Vector;
                        Shift  : Natural)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   --  -----------------------------------------------------------------------
   --  Multiply every element by a scalar then right-shift
   --    Result(i) := (A(i) * Scalar) >> Shift
   --  The IEEE_Float_32 variant ignores Shift and computes A(i) * Scalar.
   --  -----------------------------------------------------------------------

   procedure Mul_Scalar (A      : SIMD_I8_Vector;
                         Scalar : Integer_8;
                         Result : in out SIMD_I8_Vector;
                         Shift  : Natural)
      with Pre => A'Length = Result'Length;

   procedure Mul_Scalar (A      : SIMD_I16_Vector;
                         Scalar : Integer_16;
                         Result : in out SIMD_I16_Vector;
                         Shift  : Natural)
      with Pre => A'Length = Result'Length;

   procedure Mul_Scalar (A      : SIMD_I32_Vector;
                         Scalar : Integer_32;
                         Result : in out SIMD_I32_Vector;
                         Shift  : Natural)
      with Pre => A'Length = Result'Length;

   procedure Mul_Scalar (A      : SIMD_F32_Vector;
                         Scalar : IEEE_Float_32;
                         Result : in out SIMD_F32_Vector)
      with Pre => A'Length = Result'Length;

   --  -----------------------------------------------------------------------
   --  Widening element-wise multiply
   --    Integer_8  × Integer_8  → Integer_16  (simd_mul_i8_to_i16)
   --    Integer_16 × Integer_16 → Integer_32  (simd_mul_i16_to_i32)
   --  -----------------------------------------------------------------------

   procedure Mul_Widen (A      : SIMD_I8_Vector;
                        B      : SIMD_I8_Vector;
                        Result : in out SIMD_I16_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Mul_Widen (A      : SIMD_I16_Vector;
                        B      : SIMD_I16_Vector;
                        Result : in out SIMD_I32_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   --  -----------------------------------------------------------------------
   --  Saturating element-wise negation
   --    Result(i) := -A(i)  (saturates: e.g. Integer_8 -128 → 127)
   --  -----------------------------------------------------------------------

   procedure Neg (A      : SIMD_I8_Vector;
                  Result : in out SIMD_I8_Vector)
      with Pre => A'Length = Result'Length;

   procedure Neg (A      : SIMD_I16_Vector;
                  Result : in out SIMD_I16_Vector)
      with Pre => A'Length = Result'Length;

   procedure Neg (A      : SIMD_I32_Vector;
                  Result : in out SIMD_I32_Vector)
      with Pre => A'Length = Result'Length;

   procedure Neg (A      : SIMD_F32_Vector;
                  Result : in out SIMD_F32_Vector)
      with Pre => A'Length = Result'Length;

   --  -----------------------------------------------------------------------
   --  Saturating absolute value
   --    Result(i) := |A(i)|  (saturates: e.g. Integer_8 -128 → 127)
   --  -----------------------------------------------------------------------

   procedure Abs_Val (A      : SIMD_I8_Vector;
                      Result : in out SIMD_I8_Vector)
      with Pre => A'Length = Result'Length;

   procedure Abs_Val (A      : SIMD_I16_Vector;
                      Result : in out SIMD_I16_Vector)
      with Pre => A'Length = Result'Length;

   procedure Abs_Val (A      : SIMD_I32_Vector;
                      Result : in out SIMD_I32_Vector)
      with Pre => A'Length = Result'Length;

   procedure Abs_Val (A      : SIMD_F32_Vector;
                      Result : in out SIMD_F32_Vector)
      with Pre => A'Length = Result'Length;

   --  -----------------------------------------------------------------------
   --  Sum reduction: accumulate all elements into a single scalar.
   --  Integer variants accumulate into Integer_32; behaviour undefined on overflow.
   --  -----------------------------------------------------------------------

   function Sum (A : SIMD_I8_Vector)    return Integer_32;
   function Sum (A : SIMD_I16_Vector)   return Integer_32;
   function Sum (A : SIMD_I32_Vector)   return Integer_32;
   function Sum (A : SIMD_F32_Vector) return IEEE_Float_32;

   --  -----------------------------------------------------------------------
   --  Dot-product reduction: sum(A(i) * B(i))
   --  Integer variants accumulate into Integer_32 (overflow undefined).
   --  -----------------------------------------------------------------------

   function Dot_Product (A : SIMD_I8_Vector;    B : SIMD_I8_Vector)    return Integer_32
      with Pre => A'Length = B'Length;

   function Dot_Product (A : SIMD_I16_Vector;   B : SIMD_I16_Vector)   return Integer_32
      with Pre => A'Length = B'Length;

   function Dot_Product (A : SIMD_I32_Vector;   B : SIMD_I32_Vector)   return Integer_32
      with Pre => A'Length = B'Length;

   function Dot_Product (A : SIMD_F32_Vector; B : SIMD_F32_Vector) return IEEE_Float_32
      with Pre => A'Length = B'Length;

   --  -----------------------------------------------------------------------
   --  Multiply-accumulate into a scalar accumulator
   --    Accumulator := Accumulator + sum(A(i) * Multiplier)
   --  -----------------------------------------------------------------------

   procedure MAC (A           : SIMD_I8_Vector;
                  Accumulator : in out Integer_32;
                  Multiplier  : Integer_8);

   procedure MAC (A           : SIMD_I16_Vector;
                  Accumulator : in out Integer_32;
                  Multiplier  : Integer_16);

   procedure MAC (A           : SIMD_I32_Vector;
                  Accumulator : in out Integer_32;
                  Multiplier  : Integer_32);

   procedure MAC (A           : SIMD_F32_Vector;
                  Accumulator : in out IEEE_Float_32;
                  Multiplier  : IEEE_Float_32);

   --  -----------------------------------------------------------------------
   --  ReLU with optional multiply and shift
   --    Result(i) := (if A(i) < 0 then (A(i) * Multiplier) >> Shift else A(i))
   --  Note: the upstream i32 ReLU kernel is not implemented in local assembly.
   --  -----------------------------------------------------------------------

   procedure Relu (A          : SIMD_I8_Vector;
                   Multiplier : Integer_32;
                   Shift      : Natural;
                   Result     : in out SIMD_I8_Vector)
      with Pre => A'Length = Result'Length;

   procedure Relu (A          : SIMD_I16_Vector;
                   Multiplier : Integer_32;
                   Shift      : Natural;
                   Result     : in out SIMD_I16_Vector)
      with Pre => A'Length = Result'Length;

   --  -----------------------------------------------------------------------
   --  Element-wise ceiling: Result(i) := min(A(i), Max_Val)
   --  -----------------------------------------------------------------------

   procedure Ceil (A       : SIMD_I8_Vector;
                   Result  : in out SIMD_I8_Vector;
                   Max_Val : Integer_8)
      with Pre => A'Length = Result'Length;

   procedure Ceil (A       : SIMD_I16_Vector;
                   Result  : in out SIMD_I16_Vector;
                   Max_Val : Integer_16)
      with Pre => A'Length = Result'Length;

   procedure Ceil (A       : SIMD_I32_Vector;
                   Result  : in out SIMD_I32_Vector;
                   Max_Val : Integer_32)
      with Pre => A'Length = Result'Length;

   procedure Ceil (A       : SIMD_F32_Vector;
                   Result  : in out SIMD_F32_Vector;
                   Max_Val : IEEE_Float_32)
      with Pre => A'Length = Result'Length;

   --  -----------------------------------------------------------------------
   --  Element-wise floor: Result(i) := max(A(i), Min_Val)
   --  -----------------------------------------------------------------------

   procedure Floor (A       : SIMD_I8_Vector;
                    Result  : in out SIMD_I8_Vector;
                    Min_Val : Integer_8)
      with Pre => A'Length = Result'Length;

   procedure Floor (A       : SIMD_I16_Vector;
                    Result  : in out SIMD_I16_Vector;
                    Min_Val : Integer_16)
      with Pre => A'Length = Result'Length;

   procedure Floor (A       : SIMD_I32_Vector;
                    Result  : in out SIMD_I32_Vector;
                    Min_Val : Integer_32)
      with Pre => A'Length = Result'Length;

   procedure Floor (A       : SIMD_F32_Vector;
                    Result  : in out SIMD_F32_Vector;
                    Min_Val : IEEE_Float_32)
      with Pre => A'Length = Result'Length;

   --  -----------------------------------------------------------------------
   --  Element-wise maximum: Result(i) := max(A(i), B(i))
   --  -----------------------------------------------------------------------

   procedure Max (A      : SIMD_I8_Vector;
                  B      : SIMD_I8_Vector;
                  Result : in out SIMD_I8_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Max (A      : SIMD_I16_Vector;
                  B      : SIMD_I16_Vector;
                  Result : in out SIMD_I16_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Max (A      : SIMD_I32_Vector;
                  B      : SIMD_I32_Vector;
                  Result : in out SIMD_I32_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Max (A      : SIMD_F32_Vector;
                  B      : SIMD_F32_Vector;
                  Result : in out SIMD_F32_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   --  -----------------------------------------------------------------------
   --  Element-wise minimum: Result(i) := min(A(i), B(i))
   --  -----------------------------------------------------------------------

   procedure Min (A      : SIMD_I8_Vector;
                  B      : SIMD_I8_Vector;
                  Result : in out SIMD_I8_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Min (A      : SIMD_I16_Vector;
                  B      : SIMD_I16_Vector;
                  Result : in out SIMD_I16_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Min (A      : SIMD_I32_Vector;
                  B      : SIMD_I32_Vector;
                  Result : in out SIMD_I32_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Min (A      : SIMD_F32_Vector;
                  B      : SIMD_F32_Vector;
                  Result : in out SIMD_F32_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   --  -----------------------------------------------------------------------
   --  Element-wise comparison.
   --  Result(i) := all-bits-set (0xFF / 0xFFFF / 0xFFFFFFFF) when true,
   --               zero when false.
   --  -----------------------------------------------------------------------

   procedure Compare_GT (A      : SIMD_I8_Vector;
                         B      : SIMD_I8_Vector;
                         Result : in out SIMD_I8_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Compare_GT (A      : SIMD_I16_Vector;
                         B      : SIMD_I16_Vector;
                         Result : in out SIMD_I16_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Compare_GT (A      : SIMD_I32_Vector;
                         B      : SIMD_I32_Vector;
                         Result : in out SIMD_I32_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Compare_LT (A      : SIMD_I8_Vector;
                         B      : SIMD_I8_Vector;
                         Result : in out SIMD_I8_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Compare_LT (A      : SIMD_I16_Vector;
                         B      : SIMD_I16_Vector;
                         Result : in out SIMD_I16_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Compare_LT (A      : SIMD_I32_Vector;
                         B      : SIMD_I32_Vector;
                         Result : in out SIMD_I32_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Compare_EQ (A      : SIMD_I8_Vector;
                         B      : SIMD_I8_Vector;
                         Result : in out SIMD_I8_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Compare_EQ (A      : SIMD_I16_Vector;
                         B      : SIMD_I16_Vector;
                         Result : in out SIMD_I16_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Compare_EQ (A      : SIMD_I32_Vector;
                         B      : SIMD_I32_Vector;
                         Result : in out SIMD_I32_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   --  -----------------------------------------------------------------------
   --  Bitwise operations (integer types only)
   --  -----------------------------------------------------------------------

   procedure Bitwise_And (A      : SIMD_I8_Vector;
                          B      : SIMD_I8_Vector;
                          Result : in out SIMD_I8_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Bitwise_And (A      : SIMD_I16_Vector;
                          B      : SIMD_I16_Vector;
                          Result : in out SIMD_I16_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Bitwise_And (A      : SIMD_I32_Vector;
                          B      : SIMD_I32_Vector;
                          Result : in out SIMD_I32_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Bitwise_Or (A      : SIMD_I8_Vector;
                         B      : SIMD_I8_Vector;
                         Result : in out SIMD_I8_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Bitwise_Or (A      : SIMD_I16_Vector;
                         B      : SIMD_I16_Vector;
                         Result : in out SIMD_I16_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Bitwise_Or (A      : SIMD_I32_Vector;
                         B      : SIMD_I32_Vector;
                         Result : in out SIMD_I32_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Bitwise_Xor (A      : SIMD_I8_Vector;
                          B      : SIMD_I8_Vector;
                          Result : in out SIMD_I8_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Bitwise_Xor (A      : SIMD_I16_Vector;
                          B      : SIMD_I16_Vector;
                          Result : in out SIMD_I16_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Bitwise_Xor (A      : SIMD_I32_Vector;
                          B      : SIMD_I32_Vector;
                          Result : in out SIMD_I32_Vector)
      with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Bitwise_Not (A      : SIMD_I8_Vector;
                          Result : in out SIMD_I8_Vector)
      with Pre => A'Length = Result'Length;

   procedure Bitwise_Not (A      : SIMD_I16_Vector;
                          Result : in out SIMD_I16_Vector)
      with Pre => A'Length = Result'Length;

   procedure Bitwise_Not (A      : SIMD_I32_Vector;
                          Result : in out SIMD_I32_Vector)
      with Pre => A'Length = Result'Length;

   --  -----------------------------------------------------------------------
   --  Fill operations
   --  -----------------------------------------------------------------------

   --  Set every element to zero.
   procedure Zeros (A : in out SIMD_I8_Vector);
   procedure Zeros (A : in out SIMD_I16_Vector);
   procedure Zeros (A : in out SIMD_I32_Vector);

   --  Set every element to one.
   procedure Ones (A : in out SIMD_I8_Vector);
   procedure Ones (A : in out SIMD_I16_Vector);
   procedure Ones (A : in out SIMD_I32_Vector);

   --  Set every element to Value.
   procedure Fill (A : in out SIMD_I8_Vector;   Value : Integer_8);
   procedure Fill (A : in out SIMD_I16_Vector;  Value : Integer_16);
   procedure Fill (A : in out SIMD_I32_Vector;  Value : Integer_32);

   --  -----------------------------------------------------------------------
   --  Copy
   --  -----------------------------------------------------------------------

   procedure Copy (A      : SIMD_I8_Vector;
                   Result : in out SIMD_I8_Vector)
      with Pre => A'Length = Result'Length;

   procedure Copy (A      : SIMD_I16_Vector;
                   Result : in out SIMD_I16_Vector)
      with Pre => A'Length = Result'Length;

   procedure Copy (A      : SIMD_I32_Vector;
                   Result : in out SIMD_I32_Vector)
      with Pre => A'Length = Result'Length;

   --  -----------------------------------------------------------------------
   --  Integer type conversions
   --  Widening: Integer_8→Integer_16, Integer_8→Integer_32, Integer_16→Integer_32
   --  Narrowing: Integer_16→Integer_8, Integer_32→Integer_8, Integer_32→Integer_16
   --  In all cases Result must have the same number of elements as A.
   --  -----------------------------------------------------------------------

   procedure Convert (A      : SIMD_I8_Vector;
                      Result : in out SIMD_I16_Vector)
      with Pre => A'Length = Result'Length;

   procedure Convert (A      : SIMD_I8_Vector;
                      Result : in out SIMD_I32_Vector)
      with Pre => A'Length = Result'Length;

   procedure Convert (A      : SIMD_I16_Vector;
                      Result : in out SIMD_I32_Vector)
      with Pre => A'Length = Result'Length;

end ESP32.S3.SIMD;
