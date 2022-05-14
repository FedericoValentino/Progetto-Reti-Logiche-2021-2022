--Progetto Reti Logiche 2021/2022
--Federico Valentino: 10679810
--Enrico Alessandro Maria Vento: 10680917
--Nome Progetto: Christopher
--FF: 103 LUT: 82

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity project_reti_logiche is
port (
i_clk : in std_logic;
i_rst : in std_logic;
i_start : in std_logic;
i_data : in std_logic_vector(7 downto 0);
o_address : out std_logic_vector(15 downto 0);
o_done : out std_logic;
o_en : out std_logic;
o_we : out std_logic;
o_data : out std_logic_vector (7 downto 0)
);
end project_reti_logiche;

architecture Behavioural of project_reti_logiche is

    type state_type is (
      RESTART,
      SETREAD,
      READTOTALWORDS,
      READWORD,
      FIRSTBIT,
      SETBIT,
      ELABORATEBIT_0,
      ELABORATEBIT_1,
      ELABORATEBIT_2,
      ELABORATEBIT_3,
      SETWRITE,
      WRITEWORD,
      DECREMENTTOTAL,
      DONE,
      WAITFORSTART
    );
    signal state : state_type; --Current FSM state
    signal nextState : state_type; --Next FSM state
    signal readAddress : std_logic_vector(15 downto 0); --Internal register pointing to the RAM address we are reading from
    signal totalWords : std_logic_vector(7 downto 0); --Internal counter for the number of words remaining to read
    signal currentWord : std_logic_vector(7 downto 0); --Internal register pointing to the word that is currently being computed
    signal writeAddress : std_logic_vector(15 downto 0); --Internal register pointing to the RAM address we are writing to
    signal elaborate : std_logic_vector(7 downto 0); --Internal register pointing to the currently computed word
    signal outPosition : std_logic_vector(1 downto 0); --Internal counter for the location in elaborate we are writing bits pk1 and pk2 to
    signal bitCounter : std_logic_vector(2 downto 0); --Internal counter for the total bits that have been read from the currentWord register
    signal currentBit : std_logic; --Current bit fed into the convolver
    signal convoNextState : state_type; --Internal state variable used to save at which point in the convolution we are at
    signal pk1, pk2 : std_logic; --Bits computed from currentBit
    signal readTotal : boolean; --Boolean showing if we have read the total number of words to elaborate
begin


--P0 handles the state change
P0 : process(i_rst, i_clk)
      begin
        if (i_rst = '1')  then
          state <= WAITFORSTART;
        elsif rising_edge(i_clk) then
          state <= nextState;
        end if;
end process;

--P1 is our delta function. For every state it decides where to go next.
P1 : process(i_clk, state, i_start, i_rst)
         begin
            if falling_edge(i_clk) then
                case state is
                    when RESTART =>
                        nextState <= SETREAD;

                    when SETREAD =>
                        if readTotal = false then
                          nextState <= READTOTALWORDS;
                        else
                          nextState <= READWORD;
                        end if;

                    when READTOTALWORDS =>
                        if i_data = "00000000" then
                          nextState <= DONE;
                        else
                          nextState <= SETREAD;
                        end if;

                    when READWORD =>
                        nextState <= FIRSTBIT;

                    when FIRSTBIT =>
                        nextState <= convoNextState;

                    when ELABORATEBIT_0 =>
                        nextState <= SETBIT;

                    when ELABORATEBIT_1 =>
                        nextState <= SETBIT;

                    when ELABORATEBIT_2 =>
                      nextState <= SETBIT;

                    when ELABORATEBIT_3 =>
                      nextState <= SETBIT;

                    when SETBIT =>
                      if outPosition = "11" then
                        nextState <= SETWRITE;
                      else
                        nextState <= convoNextState;
                      end if;

                    when SETWRITE =>
                      nextState <= WRITEWORD;

                    when WRITEWORD =>
                      if bitCounter = "000" then
                        nextState <= DECREMENTTOTAL;
                      else
                        nextState <= convoNextState;
                      end if;

                    when DECREMENTTOTAL =>
                      nextState <= DONE;

                    when DONE =>
                      if totalWords = "00000000" and i_start = '0' then
                        nextState <= WAITFORSTART;
                      elsif totalWords = "00000000" then
                        nextState <= DONE;
                      else
                        nextState <= SETREAD;
                      end if;

                    when WAITFORSTART =>
                      if i_start = '1' then
                        nextState <= RESTART;
                      else
                        nextState <= WAITFORSTART;
                      end if;
                end case;
            end if;
         end process;

--P2 is our lamba function. It handles the various outputs of the machine.
P2 : process(i_clk, state, i_start, i_rst)
          begin
            if falling_edge(i_clk) then
                case state is
                    when RESTART =>
                        writeAddress <= "0000001111101000";
                        readAddress <= "0000000000000000";
                        currentWord <= "00000000";
                        elaborate <= "00000000";
                        currentBit <= '0';
                        outPosition <= "00";
                        bitCounter <= "000";
                        totalWords <= "00000000";
                        convoNextState <= ELABORATEBIT_0;
                        pk1 <= '0';
                        pk2 <= '0';
                        readTotal <= false;
                        o_done <= '0';
                        o_en <= '0';
                        o_we <= '0';
                        o_data <= "00000000";

                    when SETREAD =>
                        o_en <= '1';
                        o_we <= '0';
                        o_address <= readAddress;

                    when READTOTALWORDS =>
                        totalWords <= i_data;
                        readTotal <= true;
                        readAddress <= STD_LOGIC_VECTOR(unsigned(readAddress) + 1);

                    when READWORD =>
                        currentWord <= i_data;
                        readAddress <= STD_LOGIC_VECTOR(unsigned(readAddress) + 1);

                    when FIRSTBIT =>
                        o_en <= '0';
                        currentBit <= currentWord(7);

                    when ELABORATEBIT_0 =>
                        currentWord <= STD_LOGIC_VECTOR(shift_left(unsigned(currentWord), 1));
                        if currentBit = '0' then
                            pk1 <= '0';
                            pk2 <= '0';
                            convoNextState <= ELABORATEBIT_0;
                        else
                            pk1 <= '1';
                            pk2 <= '1';
                            convoNextState <= ELABORATEBIT_2;
                        end if;

                    when ELABORATEBIT_1 =>
                        currentWord <= STD_LOGIC_VECTOR(shift_left(unsigned(currentWord), 1));
                        if currentBit = '0' then
                          pk1 <= '1';
                          pk2 <= '1';
                          convoNextState <= ELABORATEBIT_0;
                        else
                          pk1 <= '0';
                          pk2 <= '0';
                          convoNextState <= ELABORATEBIT_2;
                        end if;

                    when ELABORATEBIT_2 =>
                        currentWord <= STD_LOGIC_VECTOR(shift_left(unsigned(currentWord), 1));
                        if currentBit = '0' then
                          pk1 <= '0';
                          pk2 <= '1';
                          convoNextState <= ELABORATEBIT_1;
                        else
                          pk1 <= '1';
                          pk2 <= '0';
                          convoNextState <= ELABORATEBIT_3;
                        end if;

                    when ELABORATEBIT_3 =>
                        currentWord <= STD_LOGIC_VECTOR(shift_left(unsigned(currentWord), 1));
                        if currentBit = '0' then
                          pk1 <= '1';
                          pk2 <= '0';
                          convoNextState <= ELABORATEBIT_1;
                        else
                          pk1 <= '0';
                          pk2 <= '1';
                          convoNextState <= ELABORATEBIT_3;
                        end if;

                    when SETBIT =>
                        if outPosition = "00" then
                          elaborate(7) <= pk1;
                          elaborate(6) <= pk2;
                        elsif outPosition = "01" then
                          elaborate(5) <= pk1;
                          elaborate(4) <= pk2;
                        elsif outPosition = "10" then
                          elaborate(3) <= pk1;
                          elaborate(2) <= pk2;
                        else
                          elaborate(1) <= pk1;
                          elaborate(0) <= pk2;
                        end if;
                        outPosition <= STD_LOGIC_VECTOR(unsigned(outPosition) + 1);
                        bitCounter <= STD_LOGIC_VECTOR(unsigned(bitCounter) + 1);
                        currentBit <= currentWord(7);

                    when SETWRITE =>
                        o_en <= '1';
                        o_we <= '1';
                        o_address <= writeAddress;

                    when WRITEWORD =>
                        o_data <= elaborate;
                        outPosition <= "00";
                        writeAddress <= STD_LOGIC_VECTOR(unsigned(writeAddress) + 1);

                    when DECREMENTTOTAL =>
                        totalWords <= STD_LOGIC_VECTOR(unsigned(totalWords) - 1);
                        bitCounter <= "000";
                        o_en <= '0';
                        o_we <= '0';

                    when DONE =>
                      if totalWords = "00000000" then
                        o_done <= '1';
                      else
                        o_done <= '0';
                      end if;

                    when WAITFORSTART =>
                        if i_start = '0' then
                           o_done <= '0';
                        end if;



               end case;
              end if;
             end process;

end Behavioural;