library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity random is
    port (
        clk     : in  std_logic;
        reset   : in  std_logic;
        enable  : in  std_logic;                      -- High to generate next random number
		  seed    : in  std_logic_vector(7 downto 0);
        rand_out: out std_logic_vector(7 downto 0);   -- Random byte (1 to 255)
        rand_int: out integer range 0 to 255          -- Integer representation
    );
end entity random;

architecture Behavioral of random is

    -- SEED must NEVER be all zeros (all 0s causes the LFSR to get stuck forever)
    signal lfsr_reg : std_logic_vector(7 downto 0) := seed;
    signal feedback : std_logic;

begin

    -- Taps for 8-bit maximal-length LFSR: bits 7, 5, 4, 3 (indices for 7 downto 0)
    feedback <= lfsr_reg(7) xor lfsr_reg(5) xor lfsr_reg(4) xor lfsr_reg(3);

    process(clk, reset)
    begin
        if reset = '1' then
            lfsr_reg <= seed; -- Reset to a non-zero seed
        elsif rising_edge(clk) then
            if enable = '1' then
                -- Shift left and insert feedback bit at LSB
                lfsr_reg <= lfsr_reg(6 downto 0) & feedback;
            end if;
        end if;
    end process;

    rand_out <= lfsr_reg;
    rand_int <= to_integer(unsigned(lfsr_reg));

end architecture Behavioral;