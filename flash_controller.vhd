library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity flash_controller is
    port (
        clk          : in  std_logic;
        reset_n      : in  std_logic;
        start_save   : in  std_logic;
        start_load   : in  std_logic;
        data_in      : in  std_logic_vector(31 downto 0);
        data_out     : out std_logic_vector(31 downto 0);
        busy         : out std_logic
    );
end entity flash_controller;

architecture rtl of flash_controller is

    type state_t is (
        IDLE,
        UNPROTECT_CMD,      -- Clear write protection in CSR Addr 0
        UNPROTECT_WAIT,
        ERASE_CMD,          -- Trigger sector erase in CSR Addr 1
        ERASE_HOLD,         -- Wait 2 cycles for busy bit to latch
        WAIT_ERASE_BUSY,    -- Poll CSR Addr 1 until busy bit drops
        WRITE_WORD,         -- Assert data write
        WAIT_WRITE_ACCEPT,  -- Wait for waitrequest = '0'
        WAIT_WRITE_BUSY,    -- Wait until internal flash write finishes
        READ_WORD,          -- Assert data read
        WAIT_READ           -- Capture readdata
    );
    signal state : state_t := IDLE;
    signal wait_cnt : integer range 0 to 7 := 0;

    -- UFM Avalon-MM registers
    signal csr_addr        : std_logic := '0';
    signal csr_write       : std_logic := '0';
    signal csr_read        : std_logic := '0';
    signal csr_writedata   : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_readdata    : std_logic_vector(31 downto 0);

    signal data_write      : std_logic := '0';
    signal data_read       : std_logic := '0';
    signal data_addr       : std_logic_vector(16 downto 0) := (others => '0');
    signal data_writedata  : std_logic_vector(31 downto 0) := (others => '0');
    signal data_readdata   : std_logic_vector(31 downto 0);
    signal waitrequest     : std_logic;
    signal readdatavalid   : std_logic;

    component max10_flash is
        port (
            clock                   : in  std_logic                     := 'X';
            reset_n                 : in  std_logic                     := 'X';
            avmm_data_addr          : in  std_logic_vector(16 downto 0) := (others => 'X');
            avmm_data_read          : in  std_logic                     := 'X';
            avmm_data_writedata     : in  std_logic_vector(31 downto 0) := (others => 'X');
            avmm_data_write         : in  std_logic                     := 'X';
            avmm_data_readdata      : out std_logic_vector(31 downto 0);
            avmm_data_waitrequest   : out std_logic;
            avmm_data_readdatavalid : out std_logic;
            avmm_data_burstcount    : in  std_logic_vector(3 downto 0)  := (others => 'X');
            avmm_csr_addr           : in  std_logic                     := 'X';
            avmm_csr_read           : in  std_logic                     := 'X';
            avmm_csr_writedata      : in  std_logic_vector(31 downto 0) := (others => 'X');
            avmm_csr_write          : in  std_logic                     := 'X';
            avmm_csr_readdata       : out std_logic_vector(31 downto 0)
        );
    end component max10_flash;

begin

    busy <= '0' when state = IDLE else '1';

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state         <= IDLE;
            csr_addr      <= '0';
            csr_write     <= '0';
            csr_read      <= '0';
            csr_writedata <= (others => '0');
            data_write    <= '0';
            data_read     <= '0';
            data_addr     <= (others => '0');
            data_out      <= (others => '0');
            wait_cnt      <= 0;
        elsif rising_edge(clk) then
            case state is

                when IDLE =>
                    wait_cnt <= 0;
                    if start_save = '1' then
                        -- Step 1: Clear Sector Protection at CSR Addr 0
                        csr_addr      <= '0';
                        csr_write     <= '1';
                        csr_writedata <= (others => '1'); -- Disable protection for all sectors
                        state         <= UNPROTECT_CMD;
                    elsif start_load = '1' then
                        data_read <= '1';
                        data_addr <= (others => '0');
                        state     <= READ_WORD;
                    end if;

                when UNPROTECT_CMD =>
                    csr_write <= '0';
                    state     <= UNPROTECT_WAIT;

                when UNPROTECT_WAIT =>
                    -- Step 2: Trigger Erase on Sector 1 at CSR Addr 1
                    csr_addr      <= '1';
                    csr_write     <= '1';
                    csr_writedata <= x"00000001"; -- Sector 1 erase mask
                    state         <= ERASE_CMD;

                when ERASE_CMD =>
                    csr_write <= '0';
                    csr_read  <= '1';
                    wait_cnt  <= 0;
                    state     <= ERASE_HOLD;

                when ERASE_HOLD =>
                    -- Hold for 4 cycles to ensure IP internal busy bit registers
                    if wait_cnt < 4 then
                        wait_cnt <= wait_cnt + 1;
                    else
                        state <= WAIT_ERASE_BUSY;
                    end if;

                when WAIT_ERASE_BUSY =>
                    -- Bit 0/1 indicate erase/write operation busy
                    if csr_readdata(1 downto 0) = "00" then
                        csr_read        <= '0';
                        data_write      <= '1';
                        data_addr       <= (others => '0');
                        data_writedata  <= data_in;
                        state           <= WRITE_WORD;
                    end if;

                when WRITE_WORD =>
                    if waitrequest = '0' then
                        data_write <= '0';
                        csr_addr   <= '1';
                        csr_read   <= '1';
                        wait_cnt   <= 0;
                        state      <= WAIT_WRITE_BUSY;
                    end if;

                when WAIT_WRITE_BUSY =>
                    -- Ensure physical programming finishes
                    if wait_cnt < 4 then
                        wait_cnt <= wait_cnt + 1;
                    elsif csr_readdata(1 downto 0) = "00" then
                        csr_read <= '0';
                        state    <= IDLE;
                    end if;

                when READ_WORD =>
                    if waitrequest = '0' then
                        data_read <= '0';
                        state     <= WAIT_READ;
                    end if;

                when WAIT_READ =>
                    if readdatavalid = '1' then
                        data_out <= data_readdata;
                        state    <= IDLE;
                    end if;

                when others =>
                    state <= IDLE;

            end case;
        end if;
    end process;

    u_flash : max10_flash
        port map (
            clock                   => clk,
            reset_n                 => reset_n,
            avmm_data_addr          => data_addr,
            avmm_data_read          => data_read,
            avmm_data_write         => data_write,
            avmm_data_writedata     => data_writedata,
            avmm_data_readdata      => data_readdata,
            avmm_data_waitrequest   => waitrequest,
            avmm_data_readdatavalid => readdatavalid,
            avmm_data_burstcount    => (others => '0'),
            avmm_csr_addr           => csr_addr,
            avmm_csr_read           => csr_read,
            avmm_csr_write          => csr_write,
            avmm_csr_writedata      => csr_writedata,
            avmm_csr_readdata       => csr_readdata
        );

end architecture rtl;