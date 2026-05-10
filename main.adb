
pragma Ada_2022;
--  Compile this unit with Ada 2022 language rules.

pragma Warnings (Off, "is an internal GNAT unit");
with System.Tasking.Initialization;
pragma Elaborate_All (System.Tasking.Initialization);
pragma Warnings (On, "is an internal GNAT unit");
--  Why this block exists:
--  1) `System.Tasking.Initialization` is a GNAT internal runtime unit, so GNAT
--     normally warns when it is referenced.
--  2) We intentionally use it here because ESP-IDF uses FreeRTOS tasking, and
--     this unit initializes task-safe runtime soft links early.
--  3) `pragma Elaborate_All` forces full elaboration of this unit (and its
--     dependencies) before `Main` runs, so tasking support is ready at startup.
--  4) Warning suppression is scoped narrowly to this one internal-unit use.

with Ada.Text_IO;
--  with ESP32_GPIO;
--  with GPIO_Bindings;
--  with GPIO_IRQ;
with ESP32.S3.SIMD;
with Interfaces; use Interfaces;
with Interfaces.C;
--  Ada `with` makes a package available to this file.
--  Ada `use` imports names from a package so they can be written without prefix.
--  Example: with+use Interfaces lets us write Integer_32 instead of Interfaces.Integer_32.

procedure Main is

   use ESP32.S3.SIMD;
   use type Interfaces.C.long_long;
   use type Integer_8;
   use type Integer_16;
   use type Integer_32;
   use type IEEE_Float_32;
   --  `use type` imports only operators for that type (+, -, *, comparisons, etc.),
   --  not every identifier in the package. This keeps scope cleaner.

   --  Modular type for wrapping 32-bit arithmetic
   type Mod_Int32 is mod 2**32;
   --  `mod` defines wrap-around arithmetic (overflow wraps, like unsigned math in C).

   function esp_timer_get_time return Interfaces.C.long_long
      with Import, Convention => C, External_Name => "esp_timer_get_time";
   --  `with Import` binds this Ada function declaration to a C function.
   --  We call it like a normal Ada function, but implementation lives in ESP-IDF.

   --  Test helpers
   Pass_Count : Natural := 0;
   Fail_Count : Natural := 0;

   procedure Check (Name : String; Got, Expected : Integer_32) is
   begin
      if Got = Expected then
         Pass_Count := Pass_Count + 1;
         Ada.Text_IO.Put_Line ("  PASS  " & Name);
      else
         Fail_Count := Fail_Count + 1;
         Ada.Text_IO.Put_Line
           ("  FAIL  " & Name
            & "  got=" & Got'Image
            & "  expected=" & Expected'Image);
      end if;
   end Check;

   procedure Check_F (Name : String; Got, Expected : IEEE_Float_32;
                      Tol : IEEE_Float_32 := 0.001) is
   begin
      if abs (Got - Expected) <= Tol then
         Pass_Count := Pass_Count + 1;
         Ada.Text_IO.Put_Line ("  PASS  " & Name);
      else
         Fail_Count := Fail_Count + 1;
         Ada.Text_IO.Put_Line
           ("  FAIL  " & Name
            & "  got=" & Float (Got)'Image
            & "  expected=" & Float (Expected)'Image);
      end if;
   end Check_F;

   S32 : Integer_32  := 0;
   SF  : IEEE_Float_32 := 0.0;

   Bench_Length : constant Positive := 1024;
   Bench_Iters  : constant Positive := 64;

   type Int8_Array_Access is access all SIMD_I8_Vector;
   type Int16_Array_Access is access all SIMD_I16_Vector;
   type Int32_Array_Access is access all SIMD_I32_Vector;
   type Float32_Array_Access is access all SIMD_F32_Vector;
   --  `access` is Ada's pointer type.
   --  `access all T` means this pointer can reference any object of type T.

   BA8  : constant Int8_Array_Access := new SIMD_I8_Vector (0 .. Bench_Length - 1);
   BB8  : constant Int8_Array_Access := new SIMD_I8_Vector (0 .. Bench_Length - 1);
   BR8  : constant Int8_Array_Access := new SIMD_I8_Vector (0 .. Bench_Length - 1);

   BA16 : constant Int16_Array_Access := new SIMD_I16_Vector (0 .. Bench_Length - 1);
   BB16 : constant Int16_Array_Access := new SIMD_I16_Vector (0 .. Bench_Length - 1);
   BR16 : constant Int16_Array_Access := new SIMD_I16_Vector (0 .. Bench_Length - 1);

   BA32 : constant Int32_Array_Access := new SIMD_I32_Vector (0 .. Bench_Length - 1);
   BB32 : constant Int32_Array_Access := new SIMD_I32_Vector (0 .. Bench_Length - 1);
   BR32 : constant Int32_Array_Access := new SIMD_I32_Vector (0 .. Bench_Length - 1);

   BAF  : constant Float32_Array_Access :=
     new SIMD_F32_Vector (0 .. Bench_Length - 1);
   BBF  : constant Float32_Array_Access :=
     new SIMD_F32_Vector (0 .. Bench_Length - 1);
   BRF  : constant Float32_Array_Access :=
     new SIMD_F32_Vector (0 .. Bench_Length - 1);

   BW16 : constant Int16_Array_Access := new SIMD_I16_Vector (0 .. Bench_Length - 1);
   BW32 : constant Int32_Array_Access := new SIMD_I32_Vector (0 .. Bench_Length - 1);
   --  `new` allocates heap storage and returns an access value (pointer).

   --  Test-specific heap-allocated vectors (small buffers, 16 elements each).
   --  These avoid stack allocation for declare blocks and prevent stack overflow.
   TS8A : constant Int8_Array_Access := new SIMD_I8_Vector (0 .. 15);
   TS8B : constant Int8_Array_Access := new SIMD_I8_Vector (0 .. 15);
   TS8R : constant Int8_Array_Access := new SIMD_I8_Vector (0 .. 15);

   TO32A : constant Int32_Array_Access := new SIMD_I32_Vector (0 .. 15);
   TO32B : constant Int32_Array_Access := new SIMD_I32_Vector (0 .. 15);
   TO32R : constant Int32_Array_Access := new SIMD_I32_Vector (0 .. 15);
   TOFA  : constant Float32_Array_Access := new SIMD_F32_Vector (0 .. 15);
   TOFB  : constant Float32_Array_Access := new SIMD_F32_Vector (0 .. 15);
   TOFR  : constant Float32_Array_Access := new SIMD_F32_Vector (0 .. 15);

   TAbsI8  : constant Int8_Array_Access := new SIMD_I8_Vector (0 .. 15);
   TAbsI16 : constant Int16_Array_Access := new SIMD_I16_Vector (0 .. 15);
   TAbsI32 : constant Int32_Array_Access := new SIMD_I32_Vector (0 .. 15);
   TAbsF   : constant Float32_Array_Access := new SIMD_F32_Vector (0 .. 15);

   TReluI8  : constant Int8_Array_Access := new SIMD_I8_Vector (0 .. 15);
   TReluI16 : constant Int16_Array_Access := new SIMD_I16_Vector (0 .. 15);

   --  Reuse the shared 1K benchmark buffers for correctness tests too.
   A8  : SIMD_I8_Vector renames BA8.all;
   B8  : SIMD_I8_Vector renames BB8.all;
   R8  : SIMD_I8_Vector renames BR8.all;
   A16 : SIMD_I16_Vector renames BA16.all;
   B16 : SIMD_I16_Vector renames BB16.all;
   R16 : SIMD_I16_Vector renames BR16.all;
   A32 : SIMD_I32_Vector renames BA32.all;
   B32 : SIMD_I32_Vector renames BB32.all;
   R32 : SIMD_I32_Vector renames BR32.all;
   AF  : SIMD_F32_Vector renames BAF.all;
   BF  : SIMD_F32_Vector renames BBF.all;
   RF  : SIMD_F32_Vector renames BRF.all;
   R16W : SIMD_I16_Vector renames BW16.all;  --  widen target for i8→i16
   R32W : SIMD_I32_Vector renames BW32.all;  --  widen target for i16→i32
   --  `.all` dereferences an access value (pointer) to the actual array object.
   --  `renames` creates an alias (no copy), mainly to make code shorter/clearer.

   function Clamp_I8 (V : Long_Long_Integer) return Integer_8 is
   begin
      if V < Long_Long_Integer (Integer_8'First) then
         return Integer_8'First;
      elsif V > Long_Long_Integer (Integer_8'Last) then
         return Integer_8'Last;
      else
         return Integer_8 (V);
      end if;
   end Clamp_I8;

   function Clamp_I16 (V : Long_Long_Integer) return Integer_16 is
   begin
      if V < Long_Long_Integer (Integer_16'First) then
         return Integer_16'First;
      elsif V > Long_Long_Integer (Integer_16'Last) then
         return Integer_16'Last;
      else
         return Integer_16 (V);
      end if;
   end Clamp_I16;
   --  `'First` / `'Last` are Ada attributes giving the min/max for a type.
   --  We clamp before converting so narrowing conversions cannot overflow.


   procedure Init_Bench_Data is
   begin
      for I in BA32.all'Range loop
         BA8.all (I)  := Integer_8 (Integer (I mod 97) - 48);
         BB8.all (I)  := Integer_8 (Integer (I mod 31) + 7);
         BA16.all (I) := Integer_16 (Integer (I mod 409) - 204);
         BB16.all (I) := Integer_16 (Integer (I mod 137) + 33);
         BA32.all (I) := Integer_32 (Integer (I mod 100_003) - 50_000);
         BB32.all (I) := Integer_32 (Integer (I mod 7_001) + 123);
         BAF.all (I)  := IEEE_Float_32 (Float (Integer (I mod 113)) * 0.25);
         BBF.all (I)  := IEEE_Float_32 (Float (Integer (I mod 17)) * 0.5);
      end loop;
   end Init_Bench_Data;
   --  `'Range` means "all valid indexes of this array".
   --  Using `'Range` avoids hardcoding index limits and prevents off-by-one errors.

   procedure Run_SIMD_Suite (Checksum : in out Long_Long_Integer) is
      S_Acc : Integer_32 := 0;
      F_Acc : IEEE_Float_32 := 0.0;
      Idx : constant Natural := Bench_Length / 2;
   begin
      Add (BA8.all, BB8.all, BR8.all);
      Add (BA16.all, BB16.all, BR16.all);
      Add (BA32.all, BB32.all, BR32.all);
      Add (BAF.all, BBF.all, BRF.all);

      Add_Scalar (BA8.all, Integer_8 (3), BR8.all);
      Add_Scalar (BA16.all, Integer_16 (3), BR16.all);
      Add_Scalar (BA32.all, Integer_32 (3), BR32.all);
      Add_Scalar (BAF.all, IEEE_Float_32 (3.0), BRF.all);

      Sub (BA8.all, BB8.all, BR8.all);
      Sub (BA16.all, BB16.all, BR16.all);
      Sub (BA32.all, BB32.all, BR32.all);
      Sub (BAF.all, BBF.all, BRF.all);

      Mul_Shift (BA8.all, BB8.all, BR8.all, 1);
      Mul_Shift (BA16.all, BB16.all, BR16.all, 1);
      Mul_Shift (BA32.all, BB32.all, BR32.all, 1);
      Mul_Shift (BAF.all, BBF.all, BRF.all, 0);

      Mul_Scalar (BA8.all, Integer_8 (2), BR8.all, 1);
      Mul_Scalar (BA16.all, Integer_16 (2), BR16.all, 1);
      Mul_Scalar (BA32.all, Integer_32 (2), BR32.all, 1);
      Mul_Scalar (BAF.all, IEEE_Float_32 (2.0), BRF.all);

      Mul_Widen (BA8.all, BB8.all, BW16.all);
      Mul_Widen (BA16.all, BB16.all, BW32.all);

      Neg (BA8.all, BR8.all);
      Neg (BA16.all, BR16.all);
      Neg (BA32.all, BR32.all);
      Neg (BAF.all, BRF.all);

      Abs_Val (BA8.all, BR8.all);
      Abs_Val (BA16.all, BR16.all);
      Abs_Val (BA32.all, BR32.all);
      Abs_Val (BAF.all, BRF.all);

      S_Acc := Sum (BA8.all) + Sum (BA16.all) + Sum (BA32.all);
      F_Acc := Sum (BAF.all);
      S_Acc := S_Acc + Dot_Product (BA8.all, BB8.all)
        + Dot_Product (BA16.all, BB16.all)
        + Dot_Product (BA32.all, BB32.all);
      F_Acc := F_Acc + Dot_Product (BAF.all, BBF.all);

      MAC (BA8.all, S_Acc, Integer_8 (2));
      MAC (BA16.all, S_Acc, Integer_16 (2));
      MAC (BA32.all, S_Acc, Integer_32 (2));
      MAC (BAF.all, F_Acc, IEEE_Float_32 (2.0));

      Relu (BA8.all, 2, 1, BR8.all);
      Relu (BA16.all, 2, 1, BR16.all);

      Ceil (BA8.all, BR8.all, Integer_8 (30));
      Ceil (BA16.all, BR16.all, Integer_16 (100));
      Ceil (BA32.all, BR32.all, Integer_32 (2000));
      Ceil (BAF.all, BRF.all, IEEE_Float_32 (20.0));

      Floor (BA8.all, BR8.all, Integer_8 (-30));
      Floor (BA16.all, BR16.all, Integer_16 (-100));
      Floor (BA32.all, BR32.all, Integer_32 (-2000));
      Floor (BAF.all, BRF.all, IEEE_Float_32 (-20.0));

      Max (BA8.all, BB8.all, BR8.all);
      Max (BA16.all, BB16.all, BR16.all);
      Max (BA32.all, BB32.all, BR32.all);
      Max (BAF.all, BBF.all, BRF.all);

      Min (BA8.all, BB8.all, BR8.all);
      Min (BA16.all, BB16.all, BR16.all);
      Min (BA32.all, BB32.all, BR32.all);
      Min (BAF.all, BBF.all, BRF.all);

      Compare_GT (BA8.all, BB8.all, BR8.all);
      Compare_GT (BA16.all, BB16.all, BR16.all);
      Compare_GT (BA32.all, BB32.all, BR32.all);
      Compare_LT (BA8.all, BB8.all, BR8.all);
      Compare_LT (BA16.all, BB16.all, BR16.all);
      Compare_LT (BA32.all, BB32.all, BR32.all);
      Compare_EQ (BA8.all, BB8.all, BR8.all);
      Compare_EQ (BA16.all, BB16.all, BR16.all);
      Compare_EQ (BA32.all, BB32.all, BR32.all);

      Bitwise_And (BA8.all, BB8.all, BR8.all);
      Bitwise_And (BA16.all, BB16.all, BR16.all);
      Bitwise_And (BA32.all, BB32.all, BR32.all);
      Bitwise_Or (BA8.all, BB8.all, BR8.all);
      Bitwise_Or (BA16.all, BB16.all, BR16.all);
      Bitwise_Or (BA32.all, BB32.all, BR32.all);
      Bitwise_Xor (BA8.all, BB8.all, BR8.all);
      Bitwise_Xor (BA16.all, BB16.all, BR16.all);
      Bitwise_Xor (BA32.all, BB32.all, BR32.all);
      Bitwise_Not (BA8.all, BR8.all);
      Bitwise_Not (BA16.all, BR16.all);
      Bitwise_Not (BA32.all, BR32.all);

      Zeros (BR8.all);
      Zeros (BR16.all);
      Zeros (BR32.all);
      Ones (BR8.all);
      Ones (BR16.all);
      Ones (BR32.all);
      Fill (BR8.all, Integer_8 (7));
      Fill (BR16.all, Integer_16 (7));
      Fill (BR32.all, Integer_32 (7));
      Copy (BA8.all, BR8.all);
      Copy (BA16.all, BR16.all);
      Copy (BA32.all, BR32.all);
      Convert (BA8.all, BW16.all);
      Convert (BA8.all, BW32.all);
      Convert (BA16.all, BW32.all);

      Checksum := Checksum
        + Long_Long_Integer (BR8.all (Idx))
        + Long_Long_Integer (BR16.all (Idx))
        + Long_Long_Integer (BR32.all (Idx))
        + Long_Long_Integer (Integer (Float (BRF.all (Idx)) * 1000.0))
        + Long_Long_Integer (S_Acc)
        + Long_Long_Integer (Integer (Float (F_Acc) * 1000.0));
   end Run_SIMD_Suite;

   procedure Run_Scalar_Suite (Checksum : in out Long_Long_Integer) is
      S_Acc : Integer_32 := 0;
      F_Acc : IEEE_Float_32 := 0.0;
      Idx : constant Natural := Bench_Length / 2;
      Sh : constant Long_Long_Integer := 2 ** 1;
      Dot_Sum : Long_Long_Integer := 0;
      Mac_Sum : Long_Long_Integer := 0;
   begin
      for I in BA8.all'Range loop
         BR8.all (I) := Clamp_I8 (Long_Long_Integer (BA8.all (I) + BB8.all (I)));
         BR16.all (I) := Clamp_I16
           (Long_Long_Integer (BA16.all (I) + BB16.all (I)));
         BR32.all (I) := BA32.all (I) + BB32.all (I);
         BRF.all (I) := BAF.all (I) + BBF.all (I);

         BR8.all (I) := Clamp_I8 (Long_Long_Integer (BA8.all (I) + 3));
         BR16.all (I) := Clamp_I16 (Long_Long_Integer (BA16.all (I) + 3));
         BR32.all (I) := BA32.all (I) + 3;
         BRF.all (I) := BAF.all (I) + 3.0;

         BR8.all (I) := Clamp_I8 (Long_Long_Integer (BA8.all (I) - BB8.all (I)));
         BR16.all (I) := Clamp_I16
           (Long_Long_Integer (BA16.all (I) - BB16.all (I)));
         BR32.all (I) := BA32.all (I) - BB32.all (I);
         BRF.all (I) := BAF.all (I) - BBF.all (I);

         BR8.all (I) := Clamp_I8
           ((Long_Long_Integer (BA8.all (I)) * Long_Long_Integer (BB8.all (I)))
            / Sh);
         BR16.all (I) := Clamp_I16
           ((Long_Long_Integer (BA16.all (I)) * Long_Long_Integer (BB16.all (I)))
            / Sh);
         BR32.all (I) := BA32.all (I) * BB32.all (I) / 2;
         BRF.all (I) := BAF.all (I) * BBF.all (I);

         BW16.all (I) := Integer_16 (BA8.all (I) * BB8.all (I));
         BW32.all (I) := Integer_32 (BA16.all (I) * BB16.all (I));

         BR8.all (I) := Clamp_I8 (-Long_Long_Integer (BA8.all (I)));
         BR16.all (I) := Clamp_I16 (-Long_Long_Integer (BA16.all (I)));
         BR32.all (I) := -BA32.all (I);
         BRF.all (I) := -BAF.all (I);

         BR8.all (I) := Clamp_I8 (abs Long_Long_Integer (BA8.all (I)));
         BR16.all (I) := Clamp_I16 (abs Long_Long_Integer (BA16.all (I)));
         BR32.all (I) := abs BA32.all (I);
         BRF.all (I) := abs BAF.all (I);

             S_Acc := S_Acc
                + Integer_32 (BA8.all (I))
                + Integer_32 (BA16.all (I))
                + BA32.all (I);
         F_Acc := F_Acc + BAF.all (I);

         if BA8.all (I) < 0 then
            BR8.all (I) := Clamp_I8 (Long_Long_Integer (BA8.all (I)));
         else
            BR8.all (I) := BA8.all (I);
         end if;

         if BA16.all (I) < 0 then
            BR16.all (I) := Clamp_I16 (Long_Long_Integer (BA16.all (I)));
         else
            BR16.all (I) := BA16.all (I);
         end if;

         if BA8.all (I) > Integer_8 (30) then
            BR8.all (I) := Integer_8 (30);
         else
            BR8.all (I) := BA8.all (I);
         end if;

         if BA16.all (I) > Integer_16 (100) then
            BR16.all (I) := Integer_16 (100);
         else
            BR16.all (I) := BA16.all (I);
         end if;

         if BA32.all (I) > Integer_32 (2000) then
            BR32.all (I) := Integer_32 (2000);
         else
            BR32.all (I) := BA32.all (I);
         end if;

         if BAF.all (I) > IEEE_Float_32 (20.0) then
            BRF.all (I) := IEEE_Float_32 (20.0);
         else
            BRF.all (I) := BAF.all (I);
         end if;

         if BA8.all (I) < Integer_8 (-30) then
            BR8.all (I) := Integer_8 (-30);
         else
            BR8.all (I) := BA8.all (I);
         end if;

         if BA16.all (I) < Integer_16 (-100) then
            BR16.all (I) := Integer_16 (-100);
         else
            BR16.all (I) := BA16.all (I);
         end if;

         if BA32.all (I) < Integer_32 (-2000) then
            BR32.all (I) := Integer_32 (-2000);
         else
            BR32.all (I) := BA32.all (I);
         end if;

         if BAF.all (I) < IEEE_Float_32 (-20.0) then
            BRF.all (I) := IEEE_Float_32 (-20.0);
         else
            BRF.all (I) := BAF.all (I);
         end if;

         if BA8.all (I) > BB8.all (I) then BR8.all (I) := BA8.all (I); else BR8.all (I) := BB8.all (I); end if;
         if BA16.all (I) > BB16.all (I) then BR16.all (I) := BA16.all (I); else BR16.all (I) := BB16.all (I); end if;
         if BA32.all (I) > BB32.all (I) then BR32.all (I) := BA32.all (I); else BR32.all (I) := BB32.all (I); end if;
         if BAF.all (I) > BBF.all (I) then BRF.all (I) := BAF.all (I); else BRF.all (I) := BBF.all (I); end if;

         if BA8.all (I) < BB8.all (I) then BR8.all (I) := BA8.all (I); else BR8.all (I) := BB8.all (I); end if;
         if BA16.all (I) < BB16.all (I) then BR16.all (I) := BA16.all (I); else BR16.all (I) := BB16.all (I); end if;
         if BA32.all (I) < BB32.all (I) then BR32.all (I) := BA32.all (I); else BR32.all (I) := BB32.all (I); end if;
         if BAF.all (I) < BBF.all (I) then BRF.all (I) := BAF.all (I); else BRF.all (I) := BBF.all (I); end if;

         if BA8.all (I) > BB8.all (I) then BR8.all (I) := -1; else BR8.all (I) := 0; end if;
         if BA16.all (I) > BB16.all (I) then BR16.all (I) := -1; else BR16.all (I) := 0; end if;
         if BA32.all (I) > BB32.all (I) then BR32.all (I) := -1; else BR32.all (I) := 0; end if;

         BR8.all (I) := Integer_8 (-Integer (BA8.all (I)) - 1);
         BR16.all (I) := Integer_16 (-Integer (BA16.all (I)) - 1);
         BR32.all (I) := Integer_32 (-Long_Long_Integer (BA32.all (I)) - 1);

         BR8.all (I) := -1;
         BR16.all (I) := -1;
         BR32.all (I) := -1;

         BR8.all (I) := BA8.all (I);
         BR16.all (I) := BA16.all (I);
         BR32.all (I) := BA32.all (I);

         BW16.all (I) := Integer_16 (BA8.all (I));
         BW32.all (I) := Integer_32 (BA16.all (I));
      end loop;

      --  Mirror SIMD accumulator path: add dot products, then MAC updates.
      Dot_Sum := 0;
      for I in BA8.all'Range loop
         Dot_Sum := Dot_Sum
           + Long_Long_Integer (BA8.all (I)) * Long_Long_Integer (BB8.all (I))
           + Long_Long_Integer (BA16.all (I)) * Long_Long_Integer (BB16.all (I))
           + Long_Long_Integer (BA32.all (I)) * Long_Long_Integer (BB32.all (I));
         F_Acc := F_Acc + (BAF.all (I) * BBF.all (I));
      end loop;
      S_Acc := Integer_32 (Mod_Int32 (S_Acc) + Mod_Int32 (Dot_Sum));

      Mac_Sum := 0;
      for I in BA8.all'Range loop
         Mac_Sum := Mac_Sum
           + Long_Long_Integer (BA8.all (I)) * 2
           + Long_Long_Integer (BA16.all (I)) * 2
           + Long_Long_Integer (BA32.all (I)) * 2;
         F_Acc := F_Acc + (BAF.all (I) * 2.0);
      end loop;
      S_Acc := Integer_32 (Mod_Int32 (S_Acc) + Mod_Int32 (Mac_Sum));

      Checksum := Checksum
        + Long_Long_Integer (BR8.all (Idx))
        + Long_Long_Integer (BR16.all (Idx))
        + Long_Long_Integer (BR32.all (Idx))
        + Long_Long_Integer (Integer (Float (BRF.all (Idx)) * 1000.0))
      + Long_Long_Integer (S_Acc)
        + Long_Long_Integer (Integer (Float (F_Acc) * 1000.0));
   end Run_Scalar_Suite;

   procedure Run_Benchmarks is
      pragma Suppress (Overflow_Check);
      pragma Suppress (Range_Check);
         --  Benchmark code disables some runtime checks to reduce timing noise.
         --  Keep this limited to benchmarking sections, not general application logic.
      procedure Suspend_Scheduler
        with Import,
          Convention    => C,
          External_Name => "vTaskSuspendAll";
      function Resume_Scheduler return Interfaces.C.int
        with Import,
          Convention    => C,
          External_Name => "xTaskResumeAll";
      function Fmt_Speedup (S : Float) return String is
         I  : constant Natural := Natural (Float'Floor (S));
         D  : constant Natural := Natural ((S - Float (I)) * 10.0);
             I_Str : constant String := Natural'Image (I);
             D_Str : constant String := Natural'Image (D);
      begin
             return I_Str (I_Str'First + 1 .. I_Str'Last) & "." & D_Str (D_Str'First + 1 .. D_Str'Last);
      end Fmt_Speedup;
      T0, T1 : Interfaces.C.long_long;
      Simd_Time, Scalar_Time : Interfaces.C.long_long;
      Speedup : Float := 0.0;
      Total_Simd_Us  : Interfaces.C.long_long := 0;
      Total_Scalar_Us : Interfaces.C.long_long := 0;
      Overall_Speedup : Float := 0.0;
      Resume_Ret     : Interfaces.C.int := 0 with Unreferenced;
      --  `with Unreferenced` suppresses warnings for variables intentionally kept
      --  only for side effects/documentation (here: C API return capture).
      S_Acc : Integer_32 := 0;
      F_Acc : IEEE_Float_32 := 0.0;
      Sum_Sink_I32 : Integer_32 := 0 with Volatile;
      Sum_Sink_F32 : IEEE_Float_32 := 0.0 with Volatile;
      --  `with Volatile` tells the compiler not to optimize away reads/writes,
      --  useful in benchmarks so computed values are definitely materialized.

      procedure Print_Result (Name : String; Simd_Us, Scalar_Us : Interfaces.C.long_long) is
         S : Float := 0.0;
      begin
         if Simd_Us > 0 then
            S := Float (Scalar_Us) / Float (Simd_Us);
         end if;
         Ada.Text_IO.Put_Line
           (Name & "  " & Interfaces.C.long_long'Image (Simd_Us)
            & "  " & Interfaces.C.long_long'Image (Scalar_Us)
            & "  " & Fmt_Speedup (S) & "x");
         Total_Simd_Us := Total_Simd_Us + Simd_Us;
         Total_Scalar_Us := Total_Scalar_Us + Scalar_Us;
      end Print_Result;

   begin
      Suspend_Scheduler;
      --  Pause task scheduling so other RTOS tasks do not skew timing numbers.

         begin
            declare
               M        : Mod_Int32;
               Got_I32  : Integer_32;
               Ref_I32  : Integer_32;
               Got_F32  : IEEE_Float_32;
               Ref_F32  : IEEE_Float_32;
            begin
               Ada.Text_IO.Put_Line ("Benchmark correctness warmup checks:");
               Init_Bench_Data;

               --  Sum checks
               M := 0;
               for I in BA8.all'Range loop
                  M := M + Mod_Int32 (Integer_32 (BA8.all (I)));
               end loop;
               Ref_I32 := Integer_32 (M);
               Got_I32 := Sum (BA8.all);
               Check ("Bench Sum i8", Got_I32, Ref_I32);

               M := 0;
               for I in BA16.all'Range loop
                  M := M + Mod_Int32 (Integer_32 (BA16.all (I)));
               end loop;
               Ref_I32 := Integer_32 (M);
               Got_I32 := Sum (BA16.all);
               Check ("Bench Sum i16", Got_I32, Ref_I32);

               M := 0;
               for I in BA32.all'Range loop
                  M := M + Mod_Int32 (BA32.all (I));
               end loop;
               Ref_I32 := Integer_32 (M);
               Got_I32 := Sum (BA32.all);
               Check ("Bench Sum i32", Got_I32, Ref_I32);

               Ref_F32 := 0.0;
               for I in BAF.all'Range loop
                  Ref_F32 := Ref_F32 + BAF.all (I);
               end loop;
               Got_F32 := Sum (BAF.all);
               Check_F ("Bench Sum f32", Got_F32, Ref_F32);

               --  Dot-product checks
               M := 0;
               for I in BA8.all'Range loop
                  M := M + Mod_Int32 (Integer_32 (BA8.all (I)) * Integer_32 (BB8.all (I)));
               end loop;
               Ref_I32 := Integer_32 (M);
               Got_I32 := Dot_Product (BA8.all, BB8.all);
               Check ("Bench Dot i8", Got_I32, Ref_I32);

               M := 0;
               for I in BA16.all'Range loop
                  M := M + Mod_Int32 (Integer_32 (BA16.all (I)) * Integer_32 (BB16.all (I)));
               end loop;
               Ref_I32 := Integer_32 (M);
               Got_I32 := Dot_Product (BA16.all, BB16.all);
               Check ("Bench Dot i16", Got_I32, Ref_I32);

               M := 0;
               for I in BA32.all'Range loop
                  M := M + Mod_Int32 (BA32.all (I) * BB32.all (I));
               end loop;
               Ref_I32 := Integer_32 (M);
               Got_I32 := Dot_Product (BA32.all, BB32.all);
               Check ("Bench Dot i32", Got_I32, Ref_I32);

               Ref_F32 := 0.0;
               for I in BAF.all'Range loop
                  Ref_F32 := Ref_F32 + BAF.all (I) * BBF.all (I);
               end loop;
               Got_F32 := Dot_Product (BAF.all, BBF.all);
               Check_F ("Bench Dot f32", Got_F32, Ref_F32);

               --  MAC checks
               M := 0;
               for I in BA8.all'Range loop
                  M := M + Mod_Int32 (Integer_32 (BA8.all (I)) * 2);
               end loop;
               Ref_I32 := Integer_32 (M);
               Got_I32 := 0;
               MAC (BA8.all, Got_I32, Integer_8 (2));
               Check ("Bench MAC i8", Got_I32, Ref_I32);

               M := 0;
               for I in BA16.all'Range loop
                  M := M + Mod_Int32 (Integer_32 (BA16.all (I)) * 2);
               end loop;
               Ref_I32 := Integer_32 (M);
               Got_I32 := 0;
               MAC (BA16.all, Got_I32, Integer_16 (2));
               Check ("Bench MAC i16", Got_I32, Ref_I32);

               M := 0;
               for I in BA32.all'Range loop
                  M := M + Mod_Int32 (BA32.all (I) * 2);
               end loop;
               Ref_I32 := Integer_32 (M);
               Got_I32 := 0;
               MAC (BA32.all, Got_I32, Integer_32 (2));
               Check ("Bench MAC i32", Got_I32, Ref_I32);

               Ref_F32 := 0.0;
               for I in BAF.all'Range loop
                  Ref_F32 := Ref_F32 + BAF.all (I) * 2.0;
               end loop;
               Got_F32 := 0.0;
               MAC (BAF.all, Got_F32, IEEE_Float_32 (2.0));
               Check_F ("Bench MAC f32", Got_F32, Ref_F32);
               Ada.Text_IO.New_Line;
            end;
            --  `declare ... begin ... end;` introduces a local scope for temporary
            --  variables and helper checks inside the larger benchmark routine.

             Ada.Text_IO.New_Line;
             Ada.Text_IO.Put_Line
                ("=== Per-Function Benchmark (1024 elements, 64 iterations) ===");
             Ada.Text_IO.Put_Line
                ("Operation            SIMD_us  Scalar_us  Speedup");
             Ada.Text_IO.Put_Line
                ("─────────────────────────────────────────────────");

      --  =====================================================================
      --  Add i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Add (BA8.all, BB8.all, BR8.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;
      Sum_Sink_I32 := S_Acc;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            BR8.all (I) := Clamp_I8 (Long_Long_Integer (BA8.all (I) + BB8.all (I)));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Add i8               ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Add i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Add (BA16.all, BB16.all, BR16.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            BR16.all (I) := Clamp_I16 (Long_Long_Integer (BA16.all (I) + BB16.all (I)));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Add i16              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Add i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Add (BA32.all, BB32.all, BR32.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA32.all'Range loop
            BR32.all (I) := BA32.all (I) + BB32.all (I);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Add i32              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Add f32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Add (BAF.all, BBF.all, BRF.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BAF.all'Range loop
            BRF.all (I) := BAF.all (I) + BBF.all (I);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Add f32              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Add_Scalar i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Add_Scalar (BA8.all, Integer_8 (3), BR8.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            BR8.all (I) := Clamp_I8 (Long_Long_Integer (BA8.all (I) + 3));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Add_Scalar i8        ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Add_Scalar i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Add_Scalar (BA16.all, Integer_16 (3), BR16.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            BR16.all (I) := Clamp_I16 (Long_Long_Integer (BA16.all (I) + 3));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Add_Scalar i16       ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Add_Scalar i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Add_Scalar (BA32.all, Integer_32 (3), BR32.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA32.all'Range loop
            BR32.all (I) := BA32.all (I) + 3;
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Add_Scalar i32       ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Add_Scalar f32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Add_Scalar (BAF.all, IEEE_Float_32 (3.0), BRF.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BAF.all'Range loop
            BRF.all (I) := BAF.all (I) + 3.0;
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Add_Scalar f32       ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Sub i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Sub (BA8.all, BB8.all, BR8.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            BR8.all (I) := Clamp_I8 (Long_Long_Integer (BA8.all (I) - BB8.all (I)));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Sub i8               ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Sub i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Sub (BA16.all, BB16.all, BR16.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            BR16.all (I) := Clamp_I16 (Long_Long_Integer (BA16.all (I) - BB16.all (I)));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Sub i16              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Sub i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Sub (BA32.all, BB32.all, BR32.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA32.all'Range loop
            BR32.all (I) := BA32.all (I) - BB32.all (I);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Sub i32              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Sub f32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Sub (BAF.all, BBF.all, BRF.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BAF.all'Range loop
            BRF.all (I) := BAF.all (I) - BBF.all (I);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Sub f32              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Mul_Shift i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Mul_Shift (BA8.all, BB8.all, BR8.all, 1);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            BR8.all (I) := Clamp_I8
              ((Long_Long_Integer (BA8.all (I)) * Long_Long_Integer (BB8.all (I))) / 2);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Mul_Shift i8         ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Mul_Shift i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Mul_Shift (BA16.all, BB16.all, BR16.all, 1);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            BR16.all (I) := Clamp_I16
              ((Long_Long_Integer (BA16.all (I)) * Long_Long_Integer (BB16.all (I))) / 2);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Mul_Shift i16        ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Mul_Shift i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Mul_Shift (BA32.all, BB32.all, BR32.all, 1);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA32.all'Range loop
            BR32.all (I) := BA32.all (I) * BB32.all (I) / 2;
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Mul_Shift i32        ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Mul_Shift f32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Mul_Shift (BAF.all, BBF.all, BRF.all, 0);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BAF.all'Range loop
            BRF.all (I) := BAF.all (I) * BBF.all (I);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Mul_Shift f32        ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Mul_Scalar i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Mul_Scalar (BA8.all, Integer_8 (2), BR8.all, 1);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            BR8.all (I) := Clamp_I8 ((Long_Long_Integer (BA8.all (I)) * 2) / 2);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Mul_Scalar i8        ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Mul_Scalar i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Mul_Scalar (BA16.all, Integer_16 (2), BR16.all, 1);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            BR16.all (I) := Clamp_I16 ((Long_Long_Integer (BA16.all (I)) * 2) / 2);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Mul_Scalar i16       ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Mul_Scalar i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Mul_Scalar (BA32.all, Integer_32 (2), BR32.all, 1);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA32.all'Range loop
            BR32.all (I) := BA32.all (I) * 2 / 2;
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Mul_Scalar i32       ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Mul_Scalar f32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Mul_Scalar (BAF.all, IEEE_Float_32 (2.0), BRF.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BAF.all'Range loop
            BRF.all (I) := BAF.all (I) * 2.0;
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Mul_Scalar f32       ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Mul_Widen i8->i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Mul_Widen (BA8.all, BB8.all, BW16.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            BW16.all (I) := Integer_16 (BA8.all (I) * BB8.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Mul_Widen i8->i16    ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Mul_Widen i16->i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Mul_Widen (BA16.all, BB16.all, BW32.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            BW32.all (I) := Integer_32 (BA16.all (I) * BB16.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Mul_Widen i16->i32   ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Neg i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Neg (BA8.all, BR8.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            BR8.all (I) := Clamp_I8 (-Long_Long_Integer (BA8.all (I)));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Neg i8               ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Neg i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Neg (BA16.all, BR16.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            BR16.all (I) := Clamp_I16 (-Long_Long_Integer (BA16.all (I)));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Neg i16              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Neg i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Neg (BA32.all, BR32.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA32.all'Range loop
            BR32.all (I) := -BA32.all (I);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Neg i32              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Neg f32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Neg (BAF.all, BRF.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BAF.all'Range loop
            BRF.all (I) := -BAF.all (I);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Neg f32              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Abs_Val i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Abs_Val (BA8.all, BR8.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            BR8.all (I) := Clamp_I8 (abs Long_Long_Integer (BA8.all (I)));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Abs_Val i8           ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Abs_Val i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Abs_Val (BA16.all, BR16.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            BR16.all (I) := Clamp_I16 (abs Long_Long_Integer (BA16.all (I)));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Abs_Val i16          ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Abs_Val i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Abs_Val (BA32.all, BR32.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA32.all'Range loop
            BR32.all (I) := abs BA32.all (I);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Abs_Val i32          ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Abs_Val f32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Abs_Val (BAF.all, BRF.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BAF.all'Range loop
            BRF.all (I) := abs BAF.all (I);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Abs_Val f32          ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Sum i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         S_Acc := Sum (BA8.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         S_Acc := 0;
         for I in BA8.all'Range loop
            S_Acc := S_Acc + Integer_32 (BA8.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Sum_Sink_I32 := S_Acc;
      Print_Result ("Sum i8               ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Sum i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         S_Acc := Sum (BA16.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;
      Sum_Sink_I32 := S_Acc;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         S_Acc := 0;
         for I in BA16.all'Range loop
            S_Acc := S_Acc + Integer_32 (BA16.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Sum_Sink_I32 := S_Acc;
      Print_Result ("Sum i16              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Sum i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         S_Acc := Sum (BA32.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;
      Sum_Sink_I32 := S_Acc;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         S_Acc := 0;
         for I in BA32.all'Range loop
            S_Acc := S_Acc + BA32.all (I);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Sum_Sink_I32 := S_Acc;
      Print_Result ("Sum i32              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Sum f32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         F_Acc := Sum (BAF.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;
      Sum_Sink_F32 := F_Acc;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         F_Acc := 0.0;
         for I in BAF.all'Range loop
            F_Acc := F_Acc + BAF.all (I);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Sum_Sink_F32 := F_Acc;
      Print_Result ("Sum f32              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Dot_Product i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         S_Acc := Dot_Product (BA8.all, BB8.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;
      Sum_Sink_I32 := S_Acc;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         declare
            M : Mod_Int32 := 0;
         begin
            for I in BA8.all'Range loop
               M := M + Mod_Int32 (Integer_32 (BA8.all (I)) * Integer_32 (BB8.all (I)));
            end loop;
            S_Acc := Integer_32 (M);
         end;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Sum_Sink_I32 := S_Acc;
      Print_Result ("Dot_Product i8       ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Dot_Product i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         S_Acc := Dot_Product (BA16.all, BB16.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;
      Sum_Sink_I32 := S_Acc;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         declare
            M : Mod_Int32 := 0;
         begin
            for I in BA16.all'Range loop
               M := M + Mod_Int32 (Integer_32 (BA16.all (I)) * Integer_32 (BB16.all (I)));
            end loop;
            S_Acc := Integer_32 (M);
         end;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Sum_Sink_I32 := S_Acc;
      Print_Result ("Dot_Product i16      ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Dot_Product i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         S_Acc := Dot_Product (BA32.all, BB32.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;
      Sum_Sink_I32 := S_Acc;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         declare
            M : Mod_Int32 := 0;
         begin
            for I in BA32.all'Range loop
               M := M + Mod_Int32 (BA32.all (I) * BB32.all (I));
            end loop;
            S_Acc := Integer_32 (M);
         end;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Sum_Sink_I32 := S_Acc;
      Print_Result ("Dot_Product i32      ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Dot_Product f32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         F_Acc := Dot_Product (BAF.all, BBF.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;
      Sum_Sink_F32 := F_Acc;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         F_Acc := 0.0;
         for I in BAF.all'Range loop
            F_Acc := F_Acc + BAF.all (I) * BBF.all (I);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Sum_Sink_F32 := F_Acc;
      Print_Result ("Dot_Product f32      ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  MAC i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         S_Acc := 0;
         MAC (BA8.all, S_Acc, Integer_8 (2));
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;
      Sum_Sink_I32 := S_Acc;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         declare
            M : Mod_Int32 := 0;
         begin
            for I in BA8.all'Range loop
               M := M + Mod_Int32 (Integer_32 (BA8.all (I)) * 2);
            end loop;
            S_Acc := Integer_32 (M);
         end;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Sum_Sink_I32 := S_Acc;
      Print_Result ("MAC i8               ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  MAC i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         S_Acc := 0;
         MAC (BA16.all, S_Acc, Integer_16 (2));
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;
      Sum_Sink_I32 := S_Acc;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         declare
            M : Mod_Int32 := 0;
         begin
            for I in BA16.all'Range loop
               M := M + Mod_Int32 (Integer_32 (BA16.all (I)) * 2);
            end loop;
            S_Acc := Integer_32 (M);
         end;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Sum_Sink_I32 := S_Acc;
      Print_Result ("MAC i16              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  MAC i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         S_Acc := 0;
         MAC (BA32.all, S_Acc, Integer_32 (2));
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;
      Sum_Sink_I32 := S_Acc;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         declare
            M : Mod_Int32 := 0;
         begin
            for I in BA32.all'Range loop
               M := M + Mod_Int32 (BA32.all (I) * 2);
            end loop;
            S_Acc := Integer_32 (M);
         end;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Sum_Sink_I32 := S_Acc;
      Print_Result ("MAC i32              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  MAC f32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         F_Acc := 0.0;
         MAC (BAF.all, F_Acc, IEEE_Float_32 (2.0));
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;
      Sum_Sink_F32 := F_Acc;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         F_Acc := 0.0;
         for I in BAF.all'Range loop
            F_Acc := F_Acc + BAF.all (I) * 2.0;
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Sum_Sink_F32 := F_Acc;
      Print_Result ("MAC f32              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Relu i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Relu (BA8.all, 2, 1, BR8.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            if BA8.all (I) < 0 then
               BR8.all (I) := Clamp_I8 (Long_Long_Integer (BA8.all (I)));
            else
               BR8.all (I) := BA8.all (I);
            end if;
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Relu i8              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Relu i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Relu (BA16.all, 2, 1, BR16.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            if BA16.all (I) < 0 then
               BR16.all (I) := Clamp_I16 (Long_Long_Integer (BA16.all (I)));
            else
               BR16.all (I) := BA16.all (I);
            end if;
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Relu i16             ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Ceil i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Ceil (BA8.all, BR8.all, Integer_8 (30));
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            BR8.all (I) := (if BA8.all (I) > 30 then 30 else BA8.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Ceil i8              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Ceil i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Ceil (BA16.all, BR16.all, Integer_16 (100));
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            BR16.all (I) := (if BA16.all (I) > 100 then 100 else BA16.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Ceil i16             ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Ceil i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Ceil (BA32.all, BR32.all, Integer_32 (2000));
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA32.all'Range loop
            BR32.all (I) := (if BA32.all (I) > 2000 then 2000 else BA32.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Ceil i32             ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Ceil f32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Ceil (BAF.all, BRF.all, IEEE_Float_32 (20.0));
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BAF.all'Range loop
            BRF.all (I) := (if BAF.all (I) > 20.0 then 20.0 else BAF.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Ceil f32             ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Floor i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Floor (BA8.all, BR8.all, Integer_8 (-30));
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            BR8.all (I) := (if BA8.all (I) < -30 then -30 else BA8.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Floor i8             ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Floor i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Floor (BA16.all, BR16.all, Integer_16 (-100));
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            BR16.all (I) := (if BA16.all (I) < -100 then -100 else BA16.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Floor i16            ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Floor i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Floor (BA32.all, BR32.all, Integer_32 (-2000));
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA32.all'Range loop
            BR32.all (I) := (if BA32.all (I) < -2000 then -2000 else BA32.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Floor i32            ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Floor f32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Floor (BAF.all, BRF.all, IEEE_Float_32 (-20.0));
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BAF.all'Range loop
            BRF.all (I) := (if BAF.all (I) < -20.0 then -20.0 else BAF.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Floor f32            ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Max i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Max (BA8.all, BB8.all, BR8.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            BR8.all (I) := (if BA8.all (I) > BB8.all (I) then BA8.all (I) else BB8.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Max i8               ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Max i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Max (BA16.all, BB16.all, BR16.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            BR16.all (I) := (if BA16.all (I) > BB16.all (I) then BA16.all (I) else BB16.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Max i16              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Max i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Max (BA32.all, BB32.all, BR32.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA32.all'Range loop
            BR32.all (I) := (if BA32.all (I) > BB32.all (I) then BA32.all (I) else BB32.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Max i32              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Max f32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Max (BAF.all, BBF.all, BRF.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BAF.all'Range loop
            BRF.all (I) := (if BAF.all (I) > BBF.all (I) then BAF.all (I) else BBF.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Max f32              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Min i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Min (BA8.all, BB8.all, BR8.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            BR8.all (I) := (if BA8.all (I) < BB8.all (I) then BA8.all (I) else BB8.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Min i8               ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Min i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Min (BA16.all, BB16.all, BR16.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            BR16.all (I) := (if BA16.all (I) < BB16.all (I) then BA16.all (I) else BB16.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Min i16              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Min i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Min (BA32.all, BB32.all, BR32.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA32.all'Range loop
            BR32.all (I) := (if BA32.all (I) < BB32.all (I) then BA32.all (I) else BB32.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Min i32              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Min f32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Min (BAF.all, BBF.all, BRF.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BAF.all'Range loop
            BRF.all (I) := (if BAF.all (I) < BBF.all (I) then BAF.all (I) else BBF.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Min f32              ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Compare_GT i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Compare_GT (BA8.all, BB8.all, BR8.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            BR8.all (I) := (if BA8.all (I) > BB8.all (I) then -1 else 0);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Compare_GT i8        ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Compare_GT i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Compare_GT (BA16.all, BB16.all, BR16.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            BR16.all (I) := (if BA16.all (I) > BB16.all (I) then -1 else 0);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Compare_GT i16       ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Compare_GT i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Compare_GT (BA32.all, BB32.all, BR32.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA32.all'Range loop
            BR32.all (I) := (if BA32.all (I) > BB32.all (I) then -1 else 0);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Compare_GT i32       ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Compare_LT i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Compare_LT (BA8.all, BB8.all, BR8.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            BR8.all (I) := (if BA8.all (I) < BB8.all (I) then -1 else 0);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Compare_LT i8        ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Compare_LT i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Compare_LT (BA16.all, BB16.all, BR16.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            BR16.all (I) := (if BA16.all (I) < BB16.all (I) then -1 else 0);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Compare_LT i16       ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Compare_LT i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Compare_LT (BA32.all, BB32.all, BR32.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA32.all'Range loop
            BR32.all (I) := (if BA32.all (I) < BB32.all (I) then -1 else 0);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Compare_LT i32       ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Compare_EQ i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Compare_EQ (BA8.all, BB8.all, BR8.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            BR8.all (I) := (if BA8.all (I) = BB8.all (I) then -1 else 0);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Compare_EQ i8        ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Compare_EQ i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Compare_EQ (BA16.all, BB16.all, BR16.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            BR16.all (I) := (if BA16.all (I) = BB16.all (I) then -1 else 0);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Compare_EQ i16       ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Compare_EQ i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Compare_EQ (BA32.all, BB32.all, BR32.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA32.all'Range loop
            BR32.all (I) := (if BA32.all (I) = BB32.all (I) then -1 else 0);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Compare_EQ i32       ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Bitwise_And i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Bitwise_And (BA8.all, BB8.all, BR8.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            BR8.all (I) := BA8.all (I);  --  Placeholder
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Bitwise_And i8       ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Bitwise_And i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Bitwise_And (BA16.all, BB16.all, BR16.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            BR16.all (I) := BA16.all (I);  --  Placeholder
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Bitwise_And i16      ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Bitwise_And i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Bitwise_And (BA32.all, BB32.all, BR32.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA32.all'Range loop
            BR32.all (I) := BA32.all (I);  --  Placeholder
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Bitwise_And i32      ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Bitwise_Or i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Bitwise_Or (BA8.all, BB8.all, BR8.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            BR8.all (I) := BA8.all (I);  --  Placeholder
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Bitwise_Or i8        ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Bitwise_Or i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Bitwise_Or (BA16.all, BB16.all, BR16.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            BR16.all (I) := BA16.all (I);  --  Placeholder
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Bitwise_Or i16       ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Bitwise_Or i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Bitwise_Or (BA32.all, BB32.all, BR32.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA32.all'Range loop
            BR32.all (I) := BA32.all (I);  --  Placeholder
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Bitwise_Or i32       ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Bitwise_Xor i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Bitwise_Xor (BA8.all, BB8.all, BR8.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            BR8.all (I) := BA8.all (I);  --  Placeholder
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Bitwise_Xor i8       ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Bitwise_Xor i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Bitwise_Xor (BA16.all, BB16.all, BR16.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            BR16.all (I) := BA16.all (I);  --  Placeholder
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Bitwise_Xor i16      ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Bitwise_Xor i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Bitwise_Xor (BA32.all, BB32.all, BR32.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA32.all'Range loop
            BR32.all (I) := BA32.all (I);  --  Placeholder
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Bitwise_Xor i32      ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Bitwise_Not i8
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Bitwise_Not (BA8.all, BR8.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            BR8.all (I) := BA8.all (I);  --  Placeholder
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Bitwise_Not i8       ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Bitwise_Not i16
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Bitwise_Not (BA16.all, BR16.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            BR16.all (I) := BA16.all (I);  --  Placeholder
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Bitwise_Not i16      ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Bitwise_Not i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Bitwise_Not (BA32.all, BR32.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA32.all'Range loop
            BR32.all (I) := BA32.all (I);  --  Placeholder
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Bitwise_Not i32      ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Fill / Zeros / Ones / Copy
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Zeros (BR8.all);
         Ones (BR16.all);
         Fill (BR32.all, Integer_32 (7));
         Copy (BA8.all, BR8.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BR8.all'Range loop
            BR8.all (I) := 0;
         end loop;
         for I in BR16.all'Range loop
            BR16.all (I) := -1;
         end loop;
         for I in BR32.all'Range loop
            BR32.all (I) := 7;
         end loop;
         for I in BA8.all'Range loop
            BR8.all (I) := BA8.all (I);
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Fill/Zeros/Ones/Copy ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Convert i8->i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Convert (BA8.all, BW32.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA8.all'Range loop
            BW32.all (I) := Integer_32 (BA8.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Convert i8->i32      ", Simd_Time, Scalar_Time);

      --  =====================================================================
      --  Convert i16->i32
      --  =====================================================================
      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         Convert (BA16.all, BW32.all);
      end loop;
      T1 := esp_timer_get_time;
      Simd_Time := T1 - T0;

      Init_Bench_Data;
      T0 := esp_timer_get_time;
      for Iter in 1 .. Bench_Iters loop
         for I in BA16.all'Range loop
            BW32.all (I) := Integer_32 (BA16.all (I));
         end loop;
      end loop;
      T1 := esp_timer_get_time;
      Scalar_Time := T1 - T0;
      Print_Result ("Convert i16->i32     ", Simd_Time, Scalar_Time);

         --  Print summary
         Ada.Text_IO.Put_Line ("─────────────────────────────────────────────────");
         if Total_Simd_Us > 0 then
            Overall_Speedup := Float (Total_Scalar_Us) / Float (Total_Simd_Us);
         end if;
         Ada.Text_IO.Put_Line
           ("OVERALL              "
            & Interfaces.C.long_long'Image (Total_Simd_Us)
            & "  " & Interfaces.C.long_long'Image (Total_Scalar_Us)
            & "  " & Fmt_Speedup (Overall_Speedup) & "x");
         Ada.Text_IO.New_Line;
      exception
         when others =>
            Resume_Ret := Resume_Scheduler;
            raise;
      end;
      --  Ensure scheduler is resumed even if something raises an exception.

      Resume_Ret := Resume_Scheduler;
   end Run_Benchmarks;

begin
   --  Initialize shared 1K test vectors.
   for I in A8'Range loop
      A8 (I) := 10;
      B8 (I) := 3;
      R8 (I) := 0;
      A16 (I) := 100;
      B16 (I) := 25;
      R16 (I) := 0;
      A32 (I) := 1000;
      B32 (I) := 250;
      R32 (I) := 0;
      AF (I) := 2.0;
      BF (I) := 0.5;
      RF (I) := 0.0;
      R16W (I) := 0;
      R32W (I) := 0;
   end loop;

   Ada.Text_IO.New_Line;
   Ada.Text_IO.Put_Line ("=== ESP32S3 SIMD self-test ===");

   --  -----------------------------------------------------------------------
   --  Add
   --  -----------------------------------------------------------------------
   Add (A8, B8, R8);
   Check ("Add i8",    Integer_32 (R8 (0)),  13);
   Add (A16, B16, R16);
   Check ("Add i16",   Integer_32 (R16 (0)), 125);
   Add (A32, B32, R32);
   Check ("Add i32",   Integer_32 (R32 (0)), 1250);
   Add (AF, BF, RF);
   Check_F ("Add f32", RF (0),          2.5);

   --  -----------------------------------------------------------------------
   --  Add saturation: 120 + 20 saturates to 127 for Integer_8
   --  -----------------------------------------------------------------------
   TS8A.all := (others => 120);
   TS8B.all := (others =>  20);
   TS8R.all := (others =>   0);
   Add (TS8A.all, TS8B.all, TS8R.all);
   Check ("Add i8 saturate", Integer_32 (TS8R.all (0)), 127);

   --  -----------------------------------------------------------------------
   --  Add_Scalar
   --  -----------------------------------------------------------------------
   Add_Scalar (A8,  Integer_8  (5),   R8);
   Check ("Add_Scalar i8",    Integer_32 (R8  (0)), 15);
   Add_Scalar (A16, Integer_16 (10),  R16);
   Check ("Add_Scalar i16",   Integer_32 (R16 (0)), 110);
   Add_Scalar (A32, Integer_32 (100), R32);
   Check ("Add_Scalar i32",   Integer_32 (R32 (0)), 1100);
   Add_Scalar (AF,  IEEE_Float_32 (1.5), RF);
   Check_F ("Add_Scalar f32", RF (0),           3.5);

   --  -----------------------------------------------------------------------
   --  Sub
   --  -----------------------------------------------------------------------
   Sub (A8, B8, R8);
   Check ("Sub i8",    Integer_32 (R8  (0)), 7);
   Sub (A16, B16, R16);
   Check ("Sub i16",   Integer_32 (R16 (0)), 75);
   Sub (A32, B32, R32);
   Check ("Sub i32",   Integer_32 (R32 (0)), 750);
   Sub (AF, BF, RF);
   Check_F ("Sub f32", RF (0),           1.5);

   --  -----------------------------------------------------------------------
   --  Operator overloads
   --  -----------------------------------------------------------------------
   TO32A.all := (others => 1000);
   TO32B.all := (others => 250);
   TO32R.all := (others => 0);
   TOFA.all := (others => 2.0);
   TOFB.all := (others => 0.5);
   TOFR.all := (others => 0.0);

   TO32R.all := TO32A.all + TO32B.all;
   Check ("Op + vec i32", Integer_32 (TO32R.all (0)), 1250);
   TOFR.all := TOFA.all + TOFB.all;
   Check_F ("Op + vec f32", TOFR.all (0), 2.5);

   TO32R.all := TO32A.all - TO32B.all;
   Check ("Op - vec i32", Integer_32 (TO32R.all (0)), 750);
   TOFR.all := TOFA.all - TOFB.all;
   Check_F ("Op - vec f32", TOFR.all (0), 1.5);

   TO32R.all := -TO32A.all;
   Check ("Op unary - i32", Integer_32 (TO32R.all (0)), -1000);
   TOFR.all := -TOFA.all;
   Check_F ("Op unary - f32", TOFR.all (0), -2.0);

   TO32R.all := TO32A.all + Integer_32 (7);
   Check ("Op + scalar rhs i32", Integer_32 (TO32R.all (0)), 1007);
   TO32R.all := Integer_32 (7) + TO32A.all;
   Check ("Op + scalar lhs i32", Integer_32 (TO32R.all (0)), 1007);
   TOFR.all := TOFA.all + IEEE_Float_32 (1.5);
   Check_F ("Op + scalar rhs f32", TOFR.all (0), 3.5);
   TOFR.all := IEEE_Float_32 (1.5) + TOFA.all;
   Check_F ("Op + scalar lhs f32", TOFR.all (0), 3.5);

   TO32R.all := TO32A.all - Integer_32 (7);
   Check ("Op - scalar rhs i32", Integer_32 (TO32R.all (0)), 993);
   TO32R.all := Integer_32 (2000) - TO32A.all;
   Check ("Op - scalar lhs i32", Integer_32 (TO32R.all (0)), 1000);
   TOFR.all := TOFA.all - IEEE_Float_32 (0.5);
   Check_F ("Op - scalar rhs f32", TOFR.all (0), 1.5);
   TOFR.all := IEEE_Float_32 (5.0) - TOFA.all;
   Check_F ("Op - scalar lhs f32", TOFR.all (0), 3.0);

   TO32R.all := TO32A.all * TO32B.all;
   Check ("Op * vec i32", Integer_32 (TO32R.all (0)), 250000);
   TOFR.all := TOFA.all * TOFB.all;
   Check_F ("Op * vec f32", TOFR.all (0), 1.0);

   TO32R.all := TO32A.all * Integer_32 (3);
   Check ("Op * scalar rhs i32", Integer_32 (TO32R.all (0)), 3000);
   TO32R.all := Integer_32 (3) * TO32A.all;
   Check ("Op * scalar lhs i32", Integer_32 (TO32R.all (0)), 3000);
   TOFR.all := TOFA.all * IEEE_Float_32 (3.0);
   Check_F ("Op * scalar rhs f32", TOFR.all (0), 6.0);
   TOFR.all := IEEE_Float_32 (3.0) * TOFA.all;
   Check_F ("Op * scalar lhs f32", TOFR.all (0), 6.0);

   --  -----------------------------------------------------------------------
   --  Mul_Shift  (A(i)*B(i) >> Shift)  10*3=30 >> 1 = 15
   --  -----------------------------------------------------------------------
   Mul_Shift (A8, B8, R8, 1);
   Check ("Mul_Shift i8",    Integer_32 (R8  (0)), 15);
   Mul_Shift (A16, B16, R16, 2);  --  100*25=2500 >> 2 = 625
   Check ("Mul_Shift i16",   Integer_32 (R16 (0)), 625);
   Mul_Shift (A32, B32, R32, 3);  --  1000*250=250000 >> 3 = 31250
   Check ("Mul_Shift i32",   Integer_32 (R32 (0)), 31250);
   Mul_Shift (AF, BF, RF, 0);     --  2.0*0.5 = 1.0 (shift ignored)
   Check_F ("Mul_Shift f32", RF (0), 1.0);

   --  -----------------------------------------------------------------------
   --  Mul_Scalar  (A(i)*scalar >> shift)  10*3=30 >> 1 = 15
   --  -----------------------------------------------------------------------
   Mul_Scalar (A8,  Integer_8  (3), R8,  1);
   Check ("Mul_Scalar i8",    Integer_32 (R8  (0)), 15);
   Mul_Scalar (A16, Integer_16 (4), R16, 2);  --  100*4=400 >> 2 = 100
   Check ("Mul_Scalar i16",   Integer_32 (R16 (0)), 100);
   Mul_Scalar (A32, Integer_32 (2), R32, 1);  --  1000*2=2000 >> 1 = 1000
   Check ("Mul_Scalar i32",   Integer_32 (R32 (0)), 1000);
   Mul_Scalar (AF, IEEE_Float_32 (3.0), RF);
   Check_F ("Mul_Scalar f32", RF (0), 6.0);

   --  -----------------------------------------------------------------------
   --  Mul_Widen  i8→i16  10*3 = 30
   --  -----------------------------------------------------------------------
   Mul_Widen (A8, B8, R16W);
   Check ("Mul_Widen i8→i16",  Integer_32 (R16W (0)), 30);
   --  Mul_Widen  i16→i32  100*25 = 2500
   Mul_Widen (A16, B16, R32W);
   Check ("Mul_Widen i16→i32", Integer_32 (R32W (0)), 2500);

   --  -----------------------------------------------------------------------
   --  Neg  (-10)
   --  -----------------------------------------------------------------------
   Neg (A8,  R8);
   Check ("Neg i8",    Integer_32 (R8  (0)), -10);
   Neg (A16, R16);
   Check ("Neg i16",   Integer_32 (R16 (0)), -100);
   Neg (A32, R32);
   Check ("Neg i32",   Integer_32 (R32 (0)), -1000);
   Neg (AF, RF);
   Check_F ("Neg f32", RF (0),           -2.0);

   --  -----------------------------------------------------------------------
   --  Abs_Val  (|-10| = 10)
   --  -----------------------------------------------------------------------
   TAbsI8.all  := (others => -10);
   TAbsI16.all := (others => -100);
   TAbsI32.all := (others => -1000);
   TAbsF.all   := (others => -2.0);

   Abs_Val (TAbsI8.all,  R8);
   Check ("Abs_Val i8",    Integer_32 (R8  (0)), 10);
   Abs_Val (TAbsI16.all, R16);
   Check ("Abs_Val i16",   Integer_32 (R16 (0)), 100);
   Abs_Val (TAbsI32.all, R32);
   Check ("Abs_Val i32",   Integer_32 (R32 (0)), 1000);
   Abs_Val (TAbsF.all,  RF);
   Check_F ("Abs_Val f32", RF (0),           2.0);

   --  -----------------------------------------------------------------------
   --  Sum
   --  -----------------------------------------------------------------------
   S32 := Sum (A8);
   Check ("Sum i8",    S32, Integer_32 (10 * Bench_Length));
   S32 := Sum (A16);
   Check ("Sum i16",   S32, Integer_32 (100 * Bench_Length));
   S32 := Sum (A32);
   Check ("Sum i32",   S32, Integer_32 (1000 * Bench_Length));
   SF  := Sum (AF);
   Check_F ("Sum f32", SF, IEEE_Float_32 (2.0 * Float (Bench_Length)));

   --  -----------------------------------------------------------------------
   --  Dot_Product
   --  -----------------------------------------------------------------------
   S32 := Dot_Product (A8, B8);
   Check ("Dot_Product i8",    S32, Integer_32 (10 * 3 * Bench_Length));
   S32 := Dot_Product (A16, B16);
   Check ("Dot_Product i16",   S32, Integer_32 (100 * 25 * Bench_Length));
   S32 := Dot_Product (A32, B32);
   Check ("Dot_Product i32",   S32, Integer_32 (1000 * 250 * Bench_Length));
   SF  := Dot_Product (AF, BF);
   Check_F ("Dot_Product f32", SF, IEEE_Float_32 (Float (Bench_Length)));

   --  -----------------------------------------------------------------------
   --  MAC  accumulator += sum(A(i) * multiplier)
   --  accumulator += sum(A(i) * multiplier)
   --  -----------------------------------------------------------------------
   declare
      Acc8  : Integer_32   := 0;
      Acc16 : Integer_32   := 0;
      Acc32 : Integer_32   := 0;
      AccF  : IEEE_Float_32 := 0.0;
   begin
      MAC (A8,  Acc8,  Integer_8  (2));
      Check ("MAC i8",    Acc8,  Integer_32 (10 * 2 * Bench_Length));
      MAC (A16, Acc16, Integer_16 (2));
      Check ("MAC i16",   Acc16, Integer_32 (100 * 2 * Bench_Length));
      MAC (A32, Acc32, Integer_32 (2));
      Check ("MAC i32",   Acc32, Integer_32 (1000 * 2 * Bench_Length));
      MAC (AF,  AccF,  IEEE_Float_32 (2.0));
      Check_F ("MAC f32", AccF, IEEE_Float_32 (4.0 * Float (Bench_Length)));
   end;

   --  -----------------------------------------------------------------------
   --  Relu  max(0, A(i)*mult >> shift)  10*2 >> 1 = 10
   --  -----------------------------------------------------------------------
   Relu (A8,  2, 1, R8);
   Check ("Relu i8",  Integer_32 (R8  (0)), 10);
   Relu (A16, 2, 1, R16);
   Check ("Relu i16", Integer_32 (R16 (0)), 100);
   --  Relu with negative input is scaled by multiplier and shift.
   --  For multiplier=1, shift=0, value remains unchanged.
   TReluI8.all  := (others => -5);
   TReluI16.all := (others => -5);

   Relu (TReluI8.all,  1, 0, R8);
   Check ("Relu i8  neg×1>>0",  Integer_32 (R8  (0)), -5);
   Relu (TReluI16.all, 1, 0, R16);
   Check ("Relu i16 neg×1>>0",  Integer_32 (R16 (0)), -5);

   --  -----------------------------------------------------------------------
   --  Ceil  min(A(i), max_val)  10 clamped to 8 → 8
   --  -----------------------------------------------------------------------
   Ceil (A8,  R8,  Integer_8  (8));
   Check ("Ceil i8",    Integer_32 (R8  (0)), 8);
   Ceil (A16, R16, Integer_16 (80));
   Check ("Ceil i16",   Integer_32 (R16 (0)), 80);
   Ceil (A32, R32, Integer_32 (500));
   Check ("Ceil i32",   Integer_32 (R32 (0)), 500);
   Ceil (AF,  RF,  IEEE_Float_32 (1.5));
   Check_F ("Ceil f32", RF (0), 1.5);

   --  -----------------------------------------------------------------------
   --  Floor  max(A(i), min_val)  10 floored to 15 → 15
   --  -----------------------------------------------------------------------
   Floor (A8,  R8,  Integer_8  (15));
   Check ("Floor i8",    Integer_32 (R8  (0)), 15);
   Floor (A16, R16, Integer_16 (150));
   Check ("Floor i16",   Integer_32 (R16 (0)), 150);
   Floor (A32, R32, Integer_32 (1500));
   Check ("Floor i32",   Integer_32 (R32 (0)), 1500);
   Floor (AF,  RF,  IEEE_Float_32 (3.0));
   Check_F ("Floor f32", RF (0), 3.0);

   --  -----------------------------------------------------------------------
   --  Max  max(10, 3) = 10
   --  -----------------------------------------------------------------------
   Max (A8, B8, R8);
   Check ("Max i8",  Integer_32 (R8  (0)), 10);
   Max (A16, B16, R16);
   Check ("Max i16", Integer_32 (R16 (0)), 100);
   Max (A32, B32, R32);
   Check ("Max i32", Integer_32 (R32 (0)), 1000);
   Max (AF, BF, RF);
   Check_F ("Max f32", RF (0), 2.0);

   --  -----------------------------------------------------------------------
   --  Min  min(10, 3) = 3
   --  -----------------------------------------------------------------------
   Min (A8, B8, R8);
   Check ("Min i8",  Integer_32 (R8  (0)), 3);
   Min (A16, B16, R16);
   Check ("Min i16", Integer_32 (R16 (0)), 25);
   Min (A32, B32, R32);
   Check ("Min i32", Integer_32 (R32 (0)), 250);
   Min (AF, BF, RF);
   Check_F ("Min f32", RF (0), 0.5);

   --  -----------------------------------------------------------------------
   --  Compare_GT  10 > 3 → all-bits-set (-1 as signed), 3 > 10 → 0
   --  -----------------------------------------------------------------------
   Compare_GT (A8, B8, R8);
   Check ("Compare_GT i8  (true)",  Integer_32 (R8  (0)), -1);
   Compare_GT (B8, A8, R8);
   Check ("Compare_GT i8  (false)", Integer_32 (R8  (0)),  0);
   Compare_GT (A16, B16, R16);
   Check ("Compare_GT i16 (true)",  Integer_32 (R16 (0)), -1);
   Compare_GT (A32, B32, R32);
   Check ("Compare_GT i32 (true)",  Integer_32 (R32 (0)), -1);

   --  -----------------------------------------------------------------------
   --  Compare_LT  3 < 10 → all-bits-set (-1), 10 < 3 → 0
   --  -----------------------------------------------------------------------
   Compare_LT (B8, A8, R8);
   Check ("Compare_LT i8  (true)",  Integer_32 (R8  (0)), -1);
   Compare_LT (A8, B8, R8);
   Check ("Compare_LT i8  (false)", Integer_32 (R8  (0)),  0);
   Compare_LT (B16, A16, R16);
   Check ("Compare_LT i16 (true)",  Integer_32 (R16 (0)), -1);
   Compare_LT (B32, A32, R32);
   Check ("Compare_LT i32 (true)",  Integer_32 (R32 (0)), -1);

   --  -----------------------------------------------------------------------
   --  Compare_EQ  10 = 10 → all-bits-set (-1), 10 = 3 → 0
   --  -----------------------------------------------------------------------
   Compare_EQ (A8, A8, R8);
   Check ("Compare_EQ i8  (true)",  Integer_32 (R8  (0)), -1);
   Compare_EQ (A8, B8, R8);
   Check ("Compare_EQ i8  (false)", Integer_32 (R8  (0)),  0);
   Compare_EQ (A16, A16, R16);
   Check ("Compare_EQ i16 (true)",  Integer_32 (R16 (0)), -1);
   Compare_EQ (A32, A32, R32);
   Check ("Compare_EQ i32 (true)",  Integer_32 (R32 (0)), -1);

   --  -----------------------------------------------------------------------
   --  Bitwise And  0x0A & 0x03 = 0x02
   --  -----------------------------------------------------------------------
   Bitwise_And (A8, B8, R8);
   Check ("Bitwise_And i8",  Integer_32 (R8  (0)), 2);
   Bitwise_And (A16, B16, R16);
   Check ("Bitwise_And i16", Integer_32 (R16 (0)), 0);  --  100 & 25 = 0 (no common bits)
   Bitwise_And (A32, B32, R32);
   Check ("Bitwise_And i32", Integer_32 (R32 (0)), 232); --  1000 & 250 = 0x3E8 & 0xFA = 0xE8 = 232

   --  -----------------------------------------------------------------------
   --  Bitwise Or  0x0A | 0x03 = 0x0B = 11
   --  -----------------------------------------------------------------------
   Bitwise_Or (A8, B8, R8);
   Check ("Bitwise_Or i8",  Integer_32 (R8  (0)), 11);
   Bitwise_Or (A16, B16, R16);
   Check ("Bitwise_Or i16", Integer_32 (R16 (0)), 125); --  100 | 25 = 125
   Bitwise_Or (A32, B32, R32);
   Check ("Bitwise_Or i32", Integer_32 (R32 (0)), 1018); --  1000 | 250 = 0x3E8 | 0xFA = 0x3FA = 1018

   --  -----------------------------------------------------------------------
   --  Bitwise Xor  0x0A ^ 0x03 = 0x09 = 9
   --  -----------------------------------------------------------------------
   Bitwise_Xor (A8, B8, R8);
   Check ("Bitwise_Xor i8",  Integer_32 (R8  (0)), 9);
   Bitwise_Xor (A16, B16, R16);
   Check ("Bitwise_Xor i16", Integer_32 (R16 (0)), 125); --  100 ^ 25 = 125
   Bitwise_Xor (A32, B32, R32);
   Check ("Bitwise_Xor i32", Integer_32 (R32 (0)), 786); --  1000 ^ 250 = 0x3E8 ^ 0xFA = 0x312 = 786

   --  -----------------------------------------------------------------------
   --  Bitwise Not  ~10 = -11 (two's complement)
   --  -----------------------------------------------------------------------
   Bitwise_Not (A8,  R8);
   Check ("Bitwise_Not i8",  Integer_32 (R8  (0)), -11);
   Bitwise_Not (A16, R16);
   Check ("Bitwise_Not i16", Integer_32 (R16 (0)), -101);
   Bitwise_Not (A32, R32);
   Check ("Bitwise_Not i32", Integer_32 (R32 (0)), -1001);

   --  -----------------------------------------------------------------------
   --  Zeros / Ones / Fill
   --  -----------------------------------------------------------------------
   Zeros (R8);
   Check ("Zeros i8",  Integer_32 (R8  (0)), 0);
   Zeros (R16);
   Check ("Zeros i16", Integer_32 (R16 (0)), 0);
   Zeros (R32);
   Check ("Zeros i32", Integer_32 (R32 (0)), 0);

   Ones (R8);
   Check ("Ones i8",  Integer_32 (R8  (0)), 1);
   Ones (R16);
   Check ("Ones i16", Integer_32 (R16 (0)), 1);
   Ones (R32);
   Check ("Ones i32", Integer_32 (R32 (0)), 1);

   Fill (R8,  Integer_8  (42));
   Check ("Fill i8",  Integer_32 (R8  (0)), 42);
   Fill (R16, Integer_16 (1000));
   Check ("Fill i16", Integer_32 (R16 (0)), 1000);
   Fill (R32, Integer_32 (99999));
   Check ("Fill i32", Integer_32 (R32 (0)), 99999);

   --  -----------------------------------------------------------------------
   --  Copy
   --  -----------------------------------------------------------------------
   Copy (A8,  R8);
   Check ("Copy i8",  Integer_32 (R8  (0)), 10);
   Copy (A16, R16);
   Check ("Copy i16", Integer_32 (R16 (0)), 100);
   Copy (A32, R32);
   Check ("Copy i32", Integer_32 (R32 (0)), 1000);

   --  -----------------------------------------------------------------------
   --  Convert  (widening and narrowing)
   --  -----------------------------------------------------------------------
   Convert (A8,  R16W);
   Check ("Convert i8→i16",  Integer_32 (R16W (0)), 10);
   Convert (A8,  R32W);
   Check ("Convert i8→i32",  Integer_32 (R32W (0)), 10);
   Convert (A16, R32W);
   Check ("Convert i16→i32", Integer_32 (R32W (0)), 100);

   --  -----------------------------------------------------------------------
   --  Summary
   --  -----------------------------------------------------------------------
   Ada.Text_IO.New_Line;
   Ada.Text_IO.Put_Line
     ("=== SIMD test complete: "
      & Pass_Count'Image & " passed, "
      & Fail_Count'Image & " failed ===");
   Ada.Text_IO.New_Line;

   Run_Benchmarks;


   loop
      delay 10.0;  -- do nothing
   end loop;
   --  Keep firmware alive forever; embedded `main` usually should not return.
end Main;
