//toplevel: takes in DE1-SoC keys and switches
module part2(KEY, SW, CLOCK_50, x_, y_, colour, writeEn);
    input [3:0] KEY;
    input CLOCK_50;
    input [9:0] SW;
    output [7:0] x_;
    output [6:0] y_;
    output writeEn;
    output [2:0] colour;


    part2_drawBox p2(.iResetn(KEY[0]), .iPlotBox(KEY[1]), .iBlack(KEY[2]), .iColour(SW[9:7]), .iLoadX(KEY[3]), .iXY_Coord(SW[6:0]),
            .iClock(CLOCK_50), .oX(x_), .oY(y_), .oColour(colour), .oPlot(writeEn));
endmodule


module part2_drawBox(iResetn,iPlotBox,iBlack,iColour,iLoadX,iXY_Coord,iClock,oX,oY,oColour,oPlot);
    //VGA monitor screenn pixel size
    parameter X_SCREEN_PIXELS = 8'd160;
    parameter Y_SCREEN_PIXELS = 7'd120;

    //inputs
    input wire iResetn;
    input wire iPlotBox, iBlack, iLoadX; //from pushbutton on DE1-SoC
    input wire [2:0] iColour;
    input wire [6:0] iXY_Coord; //from switches on DE1-SoC
    input wire iClock;

    //outputs, going into VGA adapter (inside fake_fpga)
    output wire [6:0] oY;
    output wire [7:0] oX;   
    output wire oPlot; 
    output wire [2:0] oColour;

    //connections    
    wire plotDone, startPlot;
    wire [2:0] colour;
    wire [7:0] x_boxsize, x_coord;
    wire [6:0] y_boxsize, y_coord;

    controlCenter mainCtl(.resetn(iResetn), 
                        .clock(iClock),
                        .iPlotBox(iPlotBox),
                        .iBlack(iBlack), 
                        .iColour(iColour), 
                        .iLoadX(iLoadX), 
                        .iXY_Coord(iXY_Coord),
                        .xScreenSize(X_SCREEN_PIXELS),
                        .yScreenSize(X_SCREEN_PIXELS),
                        .colour(colour),
                        .x_coord(x_coord), 
                        .y_coord(y_coord), 
                        .x_boxsize(x_boxsize), 
                        .y_boxsize(y_boxsize), 
                        .startPlot(startPlot), 
                        .plotDone(plotDone));

    drawBox drawVGA(.resetn(iResetn), 
                    .clock(iClock), 
                    .colour(colour), 
                    .x_coord(x_coord), 
                    .y_coord(y_coord), 
                    .x_boxsize(x_boxsize), 
                    .y_boxsize(x_boxsize), 
                    .startPlot(startPlot), 
                    .plotDone(plotDone), 
                    .oPlot(oPlot), 
                    .oColour(oColour), 
                    .oX(oX), 
                    .oY(oY));
   
endmodule // end of part2

//controlCenter puts together mainControl and mainDatapath
module controlCenter(resetn, clock, xScreenSize, x_coord, x_boxsize, yScreenSize, y_coord, y_boxsize, iXY_Coord, iColour, iPlotBox, iBlack, iLoadX, plotDone, startPlot, colour);
    //inputs
    input resetn, clock;
    input [7:0] xScreenSize, x_coord, x_boxsize;
    input [6:0] yScreenSize, y_coord, y_boxsize;
    input [6:0] iXY_Coord;
    input [2:0] iColour;
    input iPlotBox, iBlack, iLoadX, plotDone;

    //outputs
    output startPlot;
    output [2:0] colour;


    mainControl mainC(.resetn(resetn),
                    .clk(clock), 
                    .plotBox(iPlotBox), 
                    .black(iBlack),
                    .loadx(iLoadX), 
                    .plotDone(plotDone), 
                    .ld_x_coord(ld_x_coord), 
                    .ld_y_coord(ld_y_coord), 
                    .ld_black(ld_black),
                    .drawStart(drawStart) );

    mainDatapath mainD(.resetn(resetn), 
                    .clk(clock), 
                    .iColour ( iColour),
                    .iXY_Coord(iXY_Coord),
                    .xScreenSize (xScreenSize),
                    .yScreenSize (yScreenSize),
                    .ld_x_coord(ld_x_coord), 
                    .ld_y_coord(ld_y_coord), 
                    .ld_black(ld_black),
                    .drawStart(drawStart), 
                    .colour(colour), 
                    .x_coord(x_coord), 
                    .y_coord(y_coord), 
                    .x_boxsize(x_boxsize), 
                    .y_boxsize(y_boxsize), 
                    .startPlot(startPlot)  );	
endmodule 

module mainControl(resetn, clk, plotBox, black, loadx, plotDone, ld_x_coord, ld_y_coord, ld_black, drawStart);
    //inputs
    input resetn, clk, plotBox, black, loadx, plotDone;
    
    //outputs
    output reg ld_x_coord, ld_y_coord, ld_black, drawStart;
	reg [5:0] current_state, next_state; 
    
    //define directive to add alias to state, to make it easier to read to initialize states
    localparam  S_IDLE			= 6'b0,
				S_LOAD_X        = 6'd1,
                S_LOAD_X_WAIT   = 6'd2,
                S_LOAD_Y        = 6'd3,
                S_LOAD_Y_WAIT   = 6'd4,
                S_BLACK        	= 6'd5,
                S_BLACK_WAIT   	= 6'd6,
                S_PLOT			= 6'd7, 
                S_WAIT_DONE     = 6'd8;

    
    // State diagram logic
    always@(*)
    begin: state_table 
            case (current_state)
                S_IDLE: next_state = black ? S_BLACK : (loadx ? S_LOAD_X : S_IDLE); // Loop in current state until value is input
				S_LOAD_X: next_state = S_LOAD_X_WAIT;
                S_LOAD_X_WAIT: next_state = loadx ? S_LOAD_X_WAIT : S_LOAD_Y; // Loop in current state until go signal goes low
                S_LOAD_Y: next_state = plotBox ? S_LOAD_Y_WAIT : S_LOAD_Y; // Loop in current state until value is input
                S_LOAD_Y_WAIT: next_state = plotBox ? S_LOAD_Y_WAIT : S_PLOT; // Loop in current state until go signal goes low
                S_BLACK: next_state = S_BLACK_WAIT; // Loop in current state until value is input
                S_BLACK_WAIT: next_state = black ? S_BLACK_WAIT : S_PLOT; // Loop in current state until go signal goes low
                S_PLOT: next_state = S_WAIT_DONE; // Loop in current state until value is input   
				S_WAIT_DONE: next_state = plotDone ? S_IDLE : S_WAIT_DONE;
            default: next_state = S_IDLE;
        endcase
    end
   

    // This controls each state's outputs that then feed into the main datapath
    always @(*)
    begin: enable_signals
        // By default make all our signals 0
        ld_x_coord = 1'b0;
        ld_y_coord = 1'b0;
		ld_black   = 1'b0;
        drawStart  = 1'b0; //the write enable to start drawing

        case (current_state) //WAIT states don't output anything, so we can ignore them in the case
            S_IDLE:
            begin
            end
            S_LOAD_X: begin
                ld_x_coord = 1'b1; //load y 
            end 
            S_LOAD_Y: begin ld_y_coord = 1'b1; //load y
            end
            S_BLACK: begin ld_black = 1'b1; //load the black screen
            end
            S_PLOT: begin drawStart= 1'b1; //this write enable allows the plotting/drawing to begin
            end
            S_WAIT_DONE:
            begin
            end
			default:
            begin
            end
        endcase
    end // enable_signals
   
    // current_state registers
    always@(posedge clk)
    begin: state_FFs
        if (!resetn) current_state <= S_IDLE; //if we reset, go to the idle (default state)
        else current_state <= next_state;
    end // state_FFS
endmodule		

//WARNING: Quartus gives an error (constant driver) if the same register is changed in multiple always blocks. If 
//Fix: merge all always blocks into one.

//mainDatapath is controlled by the mainControl FSM
module mainDatapath(resetn, clk, iColour, iXY_Coord, xScreenSize, yScreenSize, ld_x_coord, ld_y_coord, ld_black, drawStart, colour, x_coord, x_boxsize, y_coord, y_boxsize, startPlot);

    //inputs
    input resetn, clk;
    input [2:0] iColour;
    input [6:0] iXY_Coord;
    input [7:0] xScreenSize; 
    input [6:0] yScreenSize;
    input ld_x_coord, ld_y_coord, ld_black, drawStart;
    
    //outputs
    output reg [2:0] colour;
    output reg [7:0] x_coord, x_boxsize;
    output reg [6:0] y_coord, y_boxsize;
    output reg startPlot;

    //handles whether to start drawing or not
    always@(posedge clk) 
    begin
        if (!resetn) startPlot <= 1'b0; //clear startPlot register	
        else 
        begin
            if(drawStart) startPlot <= 1'b1;
            else startPlot <= 1'b0;
        end
    end	
		
    //handles the colour retrieval into the Colour register 
    always@(posedge clk) 
    begin
        if (!resetn) colour <= 3'b0; //clear Colour register
        else
        begin
            if (ld_black) colour <= 3'b0; //colour register retrieves black
            else if (ld_y_coord) colour <= iColour; //colour register retrieves iColour
        end
    end	
	
    //handles the x coordinate retrieval into x_coord register
    always@(posedge clk)
    begin
        if (!resetn) x_coord <= 8'b0; //clear x_coord register
        else
        begin
            if (ld_black) x_coord <= 8'b0; //set x_coord (initial x coord) to 0, in preparation to set screen to black
            else if (ld_x_coord) x_coord <= {1'b0, iXY_Coord}; //add a MSB of 0 because not enough switches to allow for 8'b for x
        end                                                    //set input (desired) iXY_Coord as initial x coord
    end
   		
    //handles the y coordinate retrieval
    always@(posedge clk)
    begin
        if (!resetn) y_coord <= 8'b0; //clear register (set initial y coord to the origin)
        else
        begin
            if (ld_black) y_coord <= 8'b0; //set y_coord (initial y coord) to 0, in preparation to set screen to black
            else if (ld_y_coord) y_coord <= iXY_Coord; //set input (desired) iXY_Coord as initial y coord
        end
    end
	

    always@(posedge clk) 
    begin
        if (!resetn) //reset the size of the screen to the standard size
        begin
            x_boxsize <= 8'b0;
            y_boxsize <= 7'b0; 		
        end
        else
        begin
            if (ld_black) //make the box the size of the screen, in preparation to set it to black
            begin
                x_boxsize <= xScreenSize;
                y_boxsize <= yScreenSize;
            end
            else if (ld_y_coord) //make the box size 4 x 4 pixels
            begin
                x_boxsize <= 8'd4;
                y_boxsize <= 8'd4; 	
            end
        end
    end

endmodule

//=============================================================================================================================
//THE FOLLOWING FSM AND DATAPATH HANDLE THE ACTUAL DRAWING OF THE PIXEL
//=============================================================================================================================

//drawBox brings box-drawing controller and datapath together
module drawBox (resetn, clock, colour, x_coord, y_coord, x_boxsize, y_boxsize, startPlot, plotDone, oPlot, oColour, oX, oY);
    //inputs
    input resetn, clock;
    input [2:0] colour;
    input [7:0] x_boxsize, x_coord;
    input [6:0] y_boxsize, y_coord;
    input wire startPlot;
    
    //outputs
    output wire plotDone, oPlot;
    output wire [2:0] oColour;  
    output wire [7:0] oX;        
    output wire [6:0] oY;  

    //connections
    wire [7:0] plot_x, target_x;
    wire [6:0] plot_y, target_y;
    wire ld_data, draw, ld_orgX;

    drawBoxControl drawCtl(.clk(clock),
                            .resetn(resetn), 
                            .startPlot(startPlot), 
                            .plot_x(plot_x), 
                            .plot_y(plot_y), 
                            .target_x(target_x),  
                            .target_y(target_y), 
                            .ld_data(ld_data), 
                            .draw(draw),
                            .ld_orgX(ld_orgX),
                            .plotDone(plotDone)
                            );
                            
    drawBoxDatapath drawDpath(.clk(clock),
                            .resetn(resetn), 
                            .colour(colour),
                            .x_coord(x_coord),
                            .y_coord(y_coord),
                            .x_boxsize(x_boxsize),
                            .y_boxsize(y_boxsize),  
                            .ld_data(ld_data), 
                            .draw(draw ),
                            .ld_orgX(ld_orgX),   
                            .plot_x(plot_x), 
                            .plot_y(plot_y), 
                            .target_x(target_x),  
                            .target_y(target_y), 						  
                            .oPlot(oPlot), 
                            .oColour(oColour), 
                            .oX(oX),
                            .oY(oY)
                            );

endmodule

//handles box drawing controller (FSM)
module drawBoxControl(clk, resetn, startPlot, plot_x, target_x, plot_y, target_y, ld_data, draw, ld_orgX, plotDone);
    //inputs
    input clk, resetn, startPlot;
	input [7:0] plot_x,	target_x;
	input [6:0] plot_y, target_y;

    //outputs
    output reg ld_data, draw, ld_orgX, plotDone;
    
    reg [5:0] current_state, next_state; 
    
    //define directive to add alias to state, to make it easier to read to initialize states
    localparam  S_IDLE	       	 = 6'd0,
                S_LOAD_DATA      = 6'd1,
                S_DRAW           = 6'd2,
				S_DONE 			 = 6'd5; //CHANGE BACK TO 3
    
    // State diagram logic
    always@(*)
    begin: state_table 
            case (current_state)
                S_IDLE: next_state = startPlot ? S_LOAD_DATA : S_IDLE;
                S_LOAD_DATA: next_state = S_DRAW;
                //if we are plotting the last pixel, then we can move on to the Done state, otherwise keep drawing \/
                S_DRAW: next_state = ((plot_x == target_x) && (plot_y == target_y)) ? S_DONE : S_DRAW; 
                S_DONE: next_state = S_IDLE;
            default: next_state = S_IDLE;
        endcase
    end

    // This controls each state's outputs that then feed into the main datapath
    always @(*)
    begin: enable_signals
        // By default make all our signals 0
        ld_data = 1'b0;
        draw = 1'b0;
        ld_orgX = 1'b0;
        plotDone = 1'b0;

        case (current_state)
            S_IDLE: 
            begin
				ld_data = 1'b0;
				draw = 1'b0;
				ld_orgX = 1'b0;
				plotDone = 1'b1;			
            end
            S_LOAD_DATA: 
            begin
                ld_data = 1'b1;
				plotDone = 1'b0;	
            end
            S_DRAW: begin draw = 1'b1;
            end
			S_DONE: begin plotDone = 1'b1;
            end
        endcase
    end // enable_signals
   
    // current_state registers
    always@(posedge clk)
    begin: state_FFs
        if (!resetn) current_state <= S_IDLE;
        else current_state <= next_state;
    end // state_FFS
endmodule

//handles the box drawing datapath
module drawBoxDatapath(clk, resetn, colour, x_coord, x_boxsize, y_coord, y_boxsize, ld_data, ld_orgX, draw, oPlot, oColour, plot_x, target_x, oX, plot_y, target_y, oY);
    
    //inputs
    input clk, resetn, ld_data, ld_orgX, draw;
	input [2:0] colour;
    input [7:0] x_coord, x_boxsize;
	input [6:0] y_coord, y_boxsize;
	
    //outputs
    output reg oPlot;
	output reg [2:0] oColour;
    output reg [7:0] plot_x, target_x, oX;
	output reg [6:0] plot_y, target_y, oY;
	
	reg [7:0] temp_x_coord; //stores x_coord, the starting pixel's x coordinate
	
	
    always@(posedge clk)
    begin
        if (!resetn) //clear the registers
        begin
            target_x <= 8'b0; 			
            target_y <= 7'b0; 	
            temp_x_coord <= 8'b0;
        end
        else
        begin
            if (ld_data)
            begin //set the target (destination) coordinates
                target_x <= (x_coord + x_boxsize - 1);		
                target_y <= (y_coord + y_boxsize - 1);
                temp_x_coord <= x_coord;
            end
        end
    end
   
   //handles the drawing on each pixel
    always@(posedge clk)
    begin
        if (!resetn) //clear all registers
        begin
            oPlot <= 1'b0;
            oX <= 8'b0;
            oY <= 7'b0;
            oColour <= 3'b0;
        end
        else
        begin
            if (draw) //take everything from the registers as output (to then throw into VGA adapters)
            begin
                oPlot <= 1'b1; //plotting is complete		
                oX <= plot_x; 
                oY <= plot_y;
                oColour <= colour;
            end
            else oPlot <= 1'b0; //if we're not drawing, i.e. we haven't drawn the pixel yet
        end
    end
	

    always@(posedge clk) 
    begin
        if (!resetn) //clear the registers
        begin
			plot_x <= 8'b0;
			plot_y <= 7'b0;
        end
        else 
        begin
            if (ld_data) //if we load the data
            begin
                plot_x <= x_coord; //plot_x is set to the initial x coord
				plot_y <= y_coord; //plot_y is set to the initial y coord
			end
			else if (plot_x == target_x) //if we reach the end of the row in the square, go down the next row fom left to right again
            begin
				plot_x <= temp_x_coord; //set plot_x back to the first x value (the first column)
				plot_y <= plot_y + 1; //increment y (go down a row to start going through the row from x_coord again)
			end
			else //if we haven't reached the end of the row yet
            begin
				plot_x <= plot_x + 1; //increment x, i.e. go to the next column...
				plot_y <= plot_y; //... on the same row
			end
        end
    end	

endmodule
//end of drawBoxDatapath module

//instead of using a counter, we're using another FSM and datapath (drawBox controller and datapath) to count the pixels drawn.