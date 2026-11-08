library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity single_digit is
	port(
		num : in integer range 0 to 9;
		HEX : out std_logic_vector(0 to 7)
	);
end entity single_digit;

architecture Behavior of single_digit is
begin
with num select
	HEX <= "00000011" when 0,
			 "10011111" when 1,
			 "00100101" when 2,
			 "00001101" when 3,
			 "10011001" when 4,
			 "01001001" when 5,
			 "11000001" when 6,
			 "00011111" when 7,
			 "00000001" when 8,
			 "00011001" when 9;
end architecture Behavior;