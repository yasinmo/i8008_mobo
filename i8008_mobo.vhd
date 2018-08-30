-- i8008_mobo - Motherboard for Intel 8008
-- By Yasin Morsli
-- Provides Interface to ROM/RAM, and other Hardware Interfaces

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i8008_mobo is
port(
    clk_50:         in      std_logic;
    ledr:           out     std_logic_vector(7 downto 0);
    ledg:           out     std_logic_vector(7 downto 0);
    key_n:          in      std_logic_vector(3 downto 0);
    
    -- VGA Signals:
    vga_r:          out     std_logic_vector(3 downto 0);
    vga_g:          out     std_logic_vector(3 downto 0);
    vga_b:          out     std_logic_vector(3 downto 0);
    vga_hsync:      out     std_logic;
    vga_vsync:      out     std_logic;
    vga_clk:        out     std_logic;
    vga_sync_n:     out     std_logic;
    vga_blank_n:    out     std_logic;
    
    -- Intel8008 Pins:
    phi1:           buffer  std_logic;
    phi2:           buffer  std_logic;
    interrupt:      out     std_logic;
    ready:          out     std_logic;
    sync:           in      std_logic;
    s:              in      std_logic_vector(2 downto 0);
    data:           inout   std_logic_vector(7 downto 0)
);
end entity;

architecture i8008_mobo_behv of i8008_mobo is
    -- Video: 128x128 internal resolution, 640x480 physical resolution (output on VGA)
    --------> scale by 3 => 384x384 internal resolution, Border: 128 left/right, 48 top, bottom
    
    -- Memory Mapping:
    -- 0x0000 - 0x1FFF: ROM (mapped to Block RAM in FPGA)
    -- 0x2000 - 0x3FFF: VRAM
    
    -- Memory Signals:
    type mem_t is array(0 to 16383) of std_logic_vector(7 downto 0);
    signal ram: mem_t;
    attribute ramstyle: string;
    attribute ramstyle of ram: signal is "M4K";
    attribute ram_init_file: string;
    attribute ram_init_file of ram: signal is "rom.mif";
    signal ram_in, ram_out: std_logic_vector(7 downto 0);
    signal ram_addr_s: std_logic_vector(13 downto 0);
    signal read_mem, write_mem: boolean;
    
    -- State Signals:
    signal st1i, st1, st2, st3, st4, st5, stop, mem_wait, t3a, stag, st3w: std_logic;
    signal cc1, cc2: std_logic;
    
    -- CPU Signals
    signal addr_s: std_logic_vector(13 downto 0);
    signal data_s: std_logic_vector(7 downto 0);
    signal io_instr, is_in_instr, is_out_instr: boolean;
    
    signal reset_s, last_reset_s, reset_trig: std_logic;
    signal sync_s, last_sync_s: std_logic;
    
    -- VGA Signals:
    signal video_cycle: boolean;
    signal video_addr_s: std_logic_vector(12 downto 0);
    signal vga_col: integer range 0 to 800; -- 48 Backporch, 640 Draw, 16 Frontporch, 96 HSYNC
    signal vga_row: integer range 0 to 525; -- 33 Backporch, 480 Draw, 10 Frontporch,  2 VSYNC
    signal vga_draw_col: integer range 0 to 640; -- 128 Black, 384 Draw, 128 Black
    signal vga_draw_row: integer range 0 to 480; --  48 Black, 384 Draw,  48 Black
    signal vga_inres_col: integer range 0 to 128;
    signal vga_inres_row: integer range 0 to 128;
    signal vga_hscale_count: integer range 0 to 3;
    signal vga_vscale_count: integer range 0 to 3;
    signal vga_draw_active_area: boolean;
    
begin
    reset_trig <= reset_s xor last_reset_s;
    interrupt <= reset_s;
    ready <= '1';
    
    --VGA Control signals:
    vga_sync_n <= '0';
    vga_blank_n <= '1';
    vga_clk <= '1' when video_cycle else '0' when not video_cycle;
    
    -- Clock Generator (phi1 and phi2)
    process(clk_50, phi1, phi2) is
        variable c: integer range 0 to 255 := 0;
    begin
        if(rising_edge(clk_50)) then
            c := c + 1;
            if(c < 25)      then phi1 <= '0'; phi2 <= '0';
            elsif(c < 50)   then phi1 <= '1'; phi2 <= '0';
            elsif(c < 75)   then phi1 <= '0'; phi2 <= '0';
            elsif(c < 100)  then phi1 <= '0'; phi2 <= '1';
            else  c := 0;        phi1 <= '0'; phi2 <= '0';
            end if;
            
            --Debug: if Sync toggles, ledr(0) is lit:
            ledr(0) <= sync_s xor last_sync_s;
        end if;
        
        -- Detect Reset toggling:
        if(rising_edge(phi1)) then
            last_reset_s <= reset_s;
            reset_s <= not key_n(3);
        end if;
        
        -- Detect Sync toggling:
        if(rising_edge(phi2)) then
            last_sync_s <= sync_s;
            sync_s <= sync;
        end if;
    end process;
    
    -- State Decoder:
    process(phi2, s, sync, stag, st2, st3, cc1, cc2) is begin
        st1i <=     s(2) and     s(1) and not s(0) and not sync and phi2;     -- s(2 downto 0) = "110"
        st1  <= not s(2) and     s(1) and not s(0) and not sync and phi2;     -- s(2 downto 0) = "010"
        st2  <=     s(2) and not s(1) and not s(0) and not sync and phi2;     -- s(2 downto 0) = "100"
        st3  <= not s(2) and not s(1) and     s(0) and not sync and phi2;     -- s(2 downto 0) = "001"
        st4  <=     s(2) and     s(1) and     s(0) and not sync and phi2;     -- s(2 downto 0) = "111"
        st5  <=     s(2) and not s(1) and     s(0) and not sync and phi2;     -- s(2 downto 0) = "101"
        stop <= not s(2) and     s(1) and     s(0) and not sync and phi2;     -- s(2 downto 0) = "011"
        mem_wait <= not s(2) and not s(1) and not s(0) and not sync and phi2; -- s(2 downto 0) = "000"
        st3w <= st3 and cc1 and cc2;
        t3a <= stag and sync;
    end process;
    
    -- Capture Address and Cycle Bits:
    process(reset_s, st1, st2, data) is begin
        -- 8 Lower Address Bits:
        if(reset_s = '1') then
            addr_s(7 downto 0) <= "00000000";
        elsif(falling_edge(st1)) then
            addr_s(7 downto 0) <= data;
        end if;
        -- 6 Upper Address Bits and Cycle Flags:
        if(reset_s = '1') then
            addr_s(13 downto 8) <= "000000";
            cc1 <= '0';
            cc2 <= '0';
        elsif(falling_edge(st2)) then
            addr_s(13 downto 8) <= data(5 downto 0);
            cc1 <= data(6);
            cc2 <= data(7);
        end if;
    end process;
    
    -- ROM Enable and Data Output Decoder:
    process(clk_50, s, reset_s, cc1, cc2, st1, st2, st3, t3a, addr_s, data, ram, ram_addr_s, video_cycle) is
        variable cpu_cycle: integer range 0 to 24;
        variable video_addr_v: std_logic_vector(13 downto 0);
    begin
        if(rising_edge(clk_50)) then
            read_mem  <= true;
            write_mem <= false;
            io_instr  <= false;
            
            video_cycle <= not video_cycle;
            cpu_cycle := cpu_cycle + 1;
            if((not video_cycle) and (cpu_cycle >= 24)) then
                data <= (others => 'Z');
                
                cpu_cycle := 0;
                
                -- Set/Reset Flip-Flop for STAG:
                if(st2 = '1') then     stag <= '1';
                elsif(st3 = '1')  then stag <= '0'; end if;
                
                if((t3a and not cc1) = '1') then
                    read_mem  <= true;
                    write_mem <= false;
                    io_instr  <= false;
                    
                    -- Distinguish In/Out Instruction:
                    if((ram_out(7 downto 6) = "01") and (ram_out(0) = '1')) then
                        if(ram_out(5 downto 4) = "00") then
                            is_in_instr <= true;
                            is_out_instr <= false;
                        else
                            is_in_instr <= false;
                            is_out_instr <= true;
                        end if;
                    else
                        is_in_instr <= false;
                        is_out_instr <= false;
                    end if;
                    
                    -- Reset (Output Instruction "RST 00" to jump to Address 0x0000):
                    if(reset_s = '1') then
                        data <= x"05";
                    else
                    -- Read from Memory:
                        data <= ram_out;
                    end if;
                elsif((t3a and cc2 and cc1) = '1') then
                    read_mem  <= false;
                    write_mem <= true;
                    io_instr  <= false;
                    -- Write to Memory:
                    ram_in <= data;
                    
                elsif(((t3a and not cc2 and cc1) = '1') and is_in_instr) then
                    -- IN Instruction
                    read_mem  <= false;
                    write_mem <= false;
                    io_instr  <= true;
                    data <= "0000" & not key_n(3 downto 0);
                    
                elsif(((st1 and not cc2 and cc1) = '1') and is_out_instr) then
                    -- OUT Instruction
                    read_mem  <= false;
                    write_mem <= false;
                    io_instr  <= true;
                    ledg <= addr_s(7 downto 0);
                end if;
                
            
            elsif(video_cycle) then
            -- Process Video (VGA at 640x480):
                video_addr_v := std_logic_vector(to_unsigned((vga_inres_row * 128) + vga_inres_col, video_addr_v'length));
                video_addr_s <= video_addr_v(13 downto 1);
                
                -- if vga_col is 799, reset back to 0 and count vga_row up:
                if(vga_col >= 799) then
                    vga_col <= 0;
                    -- if vga_row is at 524, reset back to 0:
                    if(vga_row >= 524) then
                        vga_row <= 0;
                    -- else count up:
                    else
                        vga_row <= vga_row + 1;
                    end if;
                else
                    -- count vga_col up:
                    vga_col <= vga_col + 1;
                end if;
                
                -- if vga_col is between 8 and 103 (96 Pixel), start H_SYNC Signal:
                if(vga_col >= 8 and vga_col <= 103) then
                    vga_hsync <= '0';
                else
                    vga_hsync <= '1';
                end if;
                
                -- if vga_col is between 152 and 791 (640 Pixel), start counting draw_col up:
                if((vga_col >= 152) and (vga_col <= 791)) then
                    vga_draw_col <= vga_draw_col + 1;
                    if(vga_draw_col >= 639)  then
                        -- if vga_row is between 37 and 516 (480 Lines), start counting draw_row:
                        if((vga_row >= 37) and (vga_row <= 516)) then
                            vga_draw_row <= vga_draw_row + 1;
                        else
                            vga_draw_row <= 0;
                        end if;
                    end if;
                else
                    vga_draw_col <= 0;
                end if;
                
                -- if vga_row is between 2 and 3, start V_SYNC Signal:
                if((vga_row >= 2) and (vga_row <= 3)) then
                    vga_vsync <= '0';
                else
                    vga_vsync <= '1';
                end if;
                
                -- !!!SCALE DOES NOT WORK!!!
                -- ???scrambled output???
                if((vga_draw_row >= 48) and (vga_draw_row <= 431)) then
                    if((vga_draw_col >= 128) and (vga_draw_col <= 511)) then
                        vga_draw_active_area <= true;
                        vga_hscale_count <= vga_hscale_count + 1;
                        if(vga_hscale_count >= 2) then
                            vga_hscale_count <= 0;
                            vga_inres_col <= vga_inres_col + 1;
                            if(vga_inres_col >= 127) then
                                vga_inres_col <= 0;
                                vga_vscale_count <= vga_vscale_count + 1;
                                if(vga_vscale_count >= 2) then
                                    vga_vscale_count <= 0;
                                    vga_inres_row <= vga_inres_row + 1;
                                    if(vga_inres_row >= 127) then
                                        vga_inres_row <= 0;
                                    end if;
                                end if;
                            end if;
                        end if;
                    else
                        vga_draw_active_area <= false;
                        vga_inres_col <= 0;
                        vga_hscale_count <= 0;
                    end if;
                else
                    vga_draw_active_area <= false;
                    vga_inres_col <= 0;
                    vga_inres_row <= 0;
                    vga_hscale_count <= 0;
                    vga_vscale_count <= 0;
                end if;
                
                -- vga color is always low if nothing is supposed to happen:
                vga_r <= "0000";
                vga_g <= "0000";
                vga_b <= "0000";
                    
                if(vga_draw_active_area) then
                    -- draw pixel to screen:
                    if(video_addr_v(0) = '0') then
                        vga_r <= ram_out(0) & ram_out(0) & ram_out(0) & ram_out(0);
                        vga_g <= ram_out(1) & ram_out(1) & ram_out(1) & ram_out(1);
                        vga_b <= ram_out(2) & ram_out(2) & ram_out(2) & ram_out(2);
                    else
                        vga_r <= ram_out(4) & ram_out(4) & ram_out(4) & ram_out(4);
                        vga_g <= ram_out(5) & ram_out(5) & ram_out(5) & ram_out(5);
                        vga_b <= ram_out(6) & ram_out(6) & ram_out(6) & ram_out(6);
                    end if;
                end if;
                
            end if;
        end if;
        
        
        if(rising_edge(clk_50)) then
            if(not video_cycle) then ram_addr_s <= addr_s;
            else                     ram_addr_s <= '1' & video_addr_s;
            end if;
            
            if(read_mem) then
                ram_out <= ram(to_integer(unsigned(ram_addr_s)));
            elsif(write_mem) then
                ram(to_integer(unsigned(ram_addr_s))) <= ram_in;
            end if;
        end if;
    end process;
    
end architecture;
