# Pixel Drawing via VGA

Two finite state machines (in `fsm.v`) controllers and datapaths in Verilog to draw 4x4 pixel boxes on a monitor in response to user input on the DE1-SoC development board connected via VGA connection.

---

# Setup

Required tools:
- DE1-SoC development board
- Intel Quartus Prime synthesis tool
- (Optional) ModelSim for additional simulation
- A monitor with a VGA connection

1. Connect the DE1-SoC to your computer via USB.
2. In Quartus, synthesize Verilog code in a new project and make sure it compiles without error. 
3. Upload the code to the board. This may take a while.
4. Then, connect the board to your monitor using a VGA connection and select the right souce on your monitor. 

The board is now ready to draw pixels!


# How to Use


1. Using the switches on the DE1-SoC, select pixel colour (`iColour`) using SW[7-9] and the `X_coord` (first value of iXY_Coord) with SW[0-6].
2. Load `iColour` and `X_coord` in their respective registers (see datapaths in `fsm.v`) by pressing the KEY[3] pushbutton to set iLoadX to true and then false.
3. Plot pixels on monitor by pressing the KEY[2] pushbutton to set `iPloxBox` to true and then false.
4. Clear screen using the KEY[1] or KEY[0] pushbuttons to set whole screen to black or reset screen, respectively.
5. Repeat to draw more 4x4 pixel boxes at different locations by toggling the switches and loading, plotting and clearing thereafter. 


<img width="1269" alt="image" src="https://user-images.githubusercontent.com/72678323/147271590-8368a876-ebac-411f-8267-0cab34a9f864.png">


Notes:
- VGA Controller continuously reads from memory and drives to the Video DAC.
- Memory (frame buffer) content is updated through UI.
- Here, Colour is a 3-bit bus carrying an RGB value. 
- Using one input for both X and Y reduces the number of switches needed. 

The DE1-SoC has 10 switches, 3 of which we use for the 3-bit colour bus and 7 for the X bus (add a most significant bit of 0 to allow for 2^8 = 256 x-values for a max `X_coord` of 160 px) then for the Y bus (only needs 7 bits since max Y value is 120 px and 2^7 = 128).  


Pixel box bouncing off monitor edges (like logos on screensavers) with `bouncing.v` has some bugs.
