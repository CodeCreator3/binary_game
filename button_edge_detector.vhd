library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity button_edge_detector is
    generic (
        CLK_FREQ_HZ   : integer := 50_000_000; -- 50 MHz default system clock
        DEBOUNCE_MS   : integer := 10          -- 10 ms debounce threshold
    );
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        btn_in     : in  std_logic; -- Active-high asynchronous button pin
        btn_pulse  : out std_logic  -- 1-cycle strobe on rising edge
    );
end entity button_edge_detector;

architecture rtl of button_edge_detector is

    -- Constant for debounce counter limit
    constant DEBOUNCE_LIMIT : integer := (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;

    -- Stage 1: 2-FF Synchronizer
    signal btn_sync_0 : std_logic := '0';
    signal btn_sync_1 : std_logic := '0';

    -- Stage 2: Debounce filter signals
    signal btn_debounced : std_logic := '0';
    signal counter       : integer range 0 to DEBOUNCE_LIMIT := 0;

    -- Stage 3: Edge detector register
    signal btn_debounced_prev : std_logic := '0';

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                btn_sync_0         <= '0';
                btn_sync_1         <= '0';
                btn_debounced      <= '0';
                btn_debounced_prev <= '0';
                btn_pulse          <= '0';
                counter            <= 0;
            else
                -- 1. Double-flop synchronization
                btn_sync_0 <= btn_in;
                btn_sync_1 <= btn_sync_0;

                -- 2. Debounce counter
                if btn_sync_1 /= btn_debounced then
                    if counter = DEBOUNCE_LIMIT then
                        btn_debounced <= btn_sync_1;
                        counter       <= 0;
                    else
                        counter <= counter + 1;
                    end if;
                else
                    counter <= 0;
                end if;

                -- 3. Edge detection
                btn_debounced_prev <= btn_debounced;
                
                -- High only for exactly 1 clock period on a 0 -> 1 transition
                if (btn_debounced = '1' and btn_debounced_prev = '0') then
                    btn_pulse <= '1';
                else
                    btn_pulse <= '0';
                end if;
            end if;
        end if;
    end process;

end architecture rtl;