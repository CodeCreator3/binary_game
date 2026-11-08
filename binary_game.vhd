library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity binary_game is
	port(
		SWS : in std_logic_vector(0 to 6);
		LED : out std_logic_vector(0 to 6);
		BTN0 : in std_logic;
		CLOCK: in std_logic;
		HEX0 : out std_logic_vector(0 to 7);
		HEX1 : out std_logic_vector(0 to 7);
		HEX2 : out std_logic_vector(0 to 7);
		HEX3 : out std_logic_vector(0 to 7);
		HEX4 : out std_logic_vector(0 to 7);
		HEX5 : out std_logic_vector(0 to 7)
	);
end entity binary_game;

architecture Behavior of binary_game is
	constant TICKS_PER_SEC : integer := 50_000_000;
	signal clk_ticks : integer range 0 to TICKS_PER_SEC - 1 := 0;
	signal seconds : integer := 0;
	signal enable : std_logic := '0';
	signal rand_byte : std_logic_vector(7 downto 0);
	signal rand_integer : integer range 0 to 255;
	signal rand_num : integer range 0 to 99;
	signal current_num : integer range 0 to 99;
	signal btn_pls : std_logic;
	signal correct : std_logic;
	signal points : integer range 0 to 99 := 0;
	signal countdown : integer range 0 to 30 := 30;
	signal active_game : std_logic := '0';
	signal HEX0A : std_logic_vector(0 to 7);
	signal HEX1A : std_logic_vector(0 to 7);
	signal HEX2A : std_logic_vector(0 to 7);
	signal HEX3A : std_logic_vector(0 to 7);
	signal HEX4A : std_logic_vector(0 to 7);
	signal HEX5A : std_logic_vector(0 to 7);
	signal HEX0I : std_logic_vector(0 to 7);
	signal HEX1I : std_logic_vector(0 to 7);
	signal HEX2I : std_logic_vector(0 to 7);
	signal HEX3I : std_logic_vector(0 to 7);
	signal HEX4I : std_logic_vector(0 to 7);
	signal HEX5I : std_logic_vector(0 to 7);
	signal last_score : integer range 0 to 99 := 0;
	signal record_score : integer range 0 to 99 := 0;
	signal flash_controller_busy : std_logic;
	signal start_save : std_logic;
	signal start_load : std_logic;
	signal data_in : std_logic_vector(31 downto 0);
	signal data_out : std_logic_vector(31 downto 0);
	signal seed : std_logic_vector(7 downto 0);
	signal raw_score : integer;
	signal trigger_save : std_logic;
	signal trigger_load : std_logic;
	component random is
		port(
			clk     : in  std_logic;
			reset   : in  std_logic;
			enable  : in  std_logic;                      -- High to generate next random number
			rand_out: out std_logic_vector(7 downto 0);   -- Random byte (1 to 255)
			rand_int: out integer range 0 to 255          -- Integer representation
		);
	end component;
	component two_digits is 
		port(
			num : in integer range 0 to 99;
			HEX0 : out std_logic_vector(0 to 7);
			HEX1 : out std_logic_vector(0 to 7)
		);
	end component;
	component button_edge_detector is 
		port (
			  clk        : in  std_logic;
			  rst        : in  std_logic;
			  btn_in     : in  std_logic; -- Active-high asynchronous button pin
			  btn_pulse  : out std_logic  -- 1-cycle strobe on rising edge
		 );
	end component;
	component flash_controller is
		port (
			  clk          : in  std_logic;
			  reset_n      : in  std_logic;
			  start_save   : in  std_logic;
			  start_load   : in  std_logic;
			  data_in      : in  std_logic_vector(31 downto 0);
			  data_out     : out std_logic_vector(31 downto 0);
			  busy         : out std_logic
		 );
	end component;
begin
	process(CLOCK)
		begin
			if rising_edge(CLOCK) then
				if seconds < 1 then
					raw_score <= to_integer(unsigned(data_out(15 downto 8)));
					
					-- If flash is unprogrammed (0xFF = 255) or invalid, default to 0
					if raw_score > 99 then
						 record_score <= 0;
					else
						 record_score <= raw_score;
					end if;
					seed <= data_out(7 downto 0);
				end if;
				if BTN0 = '0' and active_game = '0' then
					active_game <= '1';
					points <= 0;
					countdown <= 30;
				end if;
				if enable = '1' then
					points <= points + 1;
				end if;
				
				if clk_ticks = TICKS_PER_SEC - 1 then
					clk_ticks <= 0;
					
					seconds <= seconds + 1;
					
					if countdown = 0 then
						active_game <= '0';
						last_score <= points;
						if record_score < points then
							record_score <= points;
						end if;
					else
						countdown <= countdown - 1;
					end if;
				else
					clk_ticks <= clk_ticks + 1;
				end if;
			end if;
		end process;
	u_random : random
		port map(
			CLOCK,
			'0',
			enable,
			rand_byte,
			rand_integer
		);
	rand_num <= rand_integer * 99 / 255;
	u_button_edge_detector : button_edge_detector
		port map(
			CLOCK,
			'0',
			BTN0,
			btn_pls
		);
	enable <= btn_pls and correct;
	
	u1_two_digits : two_digits
		port map(
			rand_num,
			HEX2A,
			HEX3A
		);
	
	current_num <= to_integer(unsigned(SWS));
	u2_two_digits : two_digits
		port map(
			current_num,
			HEX0A,
			HEX1A
		);
	correct <= '1' when current_num = rand_num else '0';
--	process(btn_pls)
--		begin
--			if rising_edge(btn_pls) then
--				if rst = '0' then
--					rst <= '1';
--				end if;
--			end if;
--		end process;
	u3_two_digits : two_digits
		port map(
			countdown,
			HEX4A,
			HEX5A
		);
	LED <= SWS;
	
	HEX4I <= "01000011";
	HEX5I <= "00000001";
	
	u4_two_digits : two_digits
		port map(
			last_score,
			HEX0I,
			HEX1I
		);
		
	u5_two_digits : two_digits
		port map(
			record_score,
			HEX2I,
			HEX3I
		);
		
	u_flash_controller : flash_controller
		port map(
        CLOCK,
        '1',
        trigger_save,
        trigger_load,
        data_in,
        data_out,
        flash_controller_busy
    );
	 
	start_save <= '1' when seconds >= 1 and not active_game = '1' else '0';
	start_load <= '1' when seconds < 1 else '0';
	data_in <= "0000000000000000" & std_logic_vector(to_unsigned(record_score, 8)) & rand_byte;
	
	trigger_save <= '1' when start_save = '1' and flash_controller_busy = '0' else '0';
	trigger_load <= '1' when start_load = '1' and flash_controller_busy = '0' else '0';
	
	HEX0 <= HEX0A when active_game = '1' else HEX0I;
	HEX1 <= HEX1A when active_game = '1' else HEX1I;
	HEX2 <= HEX2A when active_game = '1' else HEX2I;
	HEX3 <= HEX3A when active_game = '1' else HEX3I;
	HEX4 <= HEX4A when active_game = '1' else HEX4I;
	HEX5 <= HEX5A when active_game = '1' else HEX5I;
end architecture Behavior;

