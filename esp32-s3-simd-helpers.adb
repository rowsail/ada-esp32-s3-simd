pragma Ada_2022;

with ESP32.S3.SIMD;
with System;

use ESP32.S3.SIMD;

package body ESP32.S3.SIMD.Helpers is

   use System;

   function First_Address (V : SIMD_I8_Vector) return Address is
   begin
      if V'Length = 0 then
         return Null_Address;
      end if;
      return V (V'First)'Address;
   end First_Address;

   function First_Address (V : SIMD_I16_Vector) return Address is
   begin
      if V'Length = 0 then
         return Null_Address;
      end if;
      return V (V'First)'Address;
   end First_Address;

   function First_Address (V : SIMD_I32_Vector) return Address is
   begin
      if V'Length = 0 then
         return Null_Address;
      end if;
      return V (V'First)'Address;
   end First_Address;

   function First_Address (V : SIMD_F32_Vector) return Address is
   begin
      if V'Length = 0 then
         return Null_Address;
      end if;
      return V (V'First)'Address;
   end First_Address;

end ESP32.S3.SIMD.Helpers;
