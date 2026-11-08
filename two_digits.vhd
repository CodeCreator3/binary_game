library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity two_digits is
	port(
		num : in integer range 0 to 99;
		HEX0 : out std_logic_vector(0 to 7);
		HEX1 : out std_logic_vector(0 to 7)
	);
end entity two_digits;

architecture Behavior of two_digits is
	signal ones_place : integer range 0 to 9;
	signal tens_place : integer range 0 to 9;
	component single_digit is 
		port(
			num : in integer range 0 to 9;
			HEX : out std_logic_vector(0 to 7)
		);
	end component;
begin
	ones_place <= num mod 10;
	tens_place <= num / 10;
	u1_single_digit : single_digit
		port map(
			ones_place,
			HEX0
		);
	u2_single_digit : single_digit
		port map(
			tens_place,
			HEX1
		);
end architecture Behavior;